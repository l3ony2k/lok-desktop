// SPDX-License-Identifier: GPL-2.0
/*
 * e820_hibfix - let hibernation resume survive a known, harmless e820 drift.
 *
 * On this machine (Google Screebo, MrChromebox coreboot + EDK2) the boot chain
 * places two small EfiACPIReclaimMemory allocations (the EFI random-seed table
 * and the EFI stub's boot memory-map copy) at slightly different addresses on
 * every boot. They change the firmware e820 table, so the x86 resume check
 * (crc32 of e820_table_firmware) always fails.
 *
 * All observed drift stays inside [win_start, win_end). The kernel is booted
 * with memmap=0x1b000$0x661a0000, so that window is never usable RAM for either
 * the image kernel or the restore kernel.
 *
 * This module replaces the checksum stored in the image header with a
 * checksum of the firmware table in which the window is normalised to a
 * single entry. On resume, if the current table normalises to the same value,
 * the stored value is swapped for the real checksum so the kernel's own check
 * passes. Any difference outside the window still makes resume fail, exactly
 * as without this module.
 */
#include <linux/module.h>
#include <linux/kprobes.h>
#include <linux/crc32.h>
#include <asm/e820/types.h>

static unsigned long win_start = 0x661a0000;
static unsigned long win_end = 0x661bb000; /* exclusive */
module_param(win_start, ulong, 0444);
module_param(win_end, ulong, 0444);
MODULE_PARM_DESC(win_start, "start of the tolerated drift window");
MODULE_PARM_DESC(win_end, "end (exclusive) of the tolerated drift window");

/* Must match arch/x86/power/hibernate.c (checked against v7.2). */
struct restore_data_record {
	unsigned long jump_address;
	unsigned long jump_address_phys;
	unsigned long cr3;
	unsigned long magic;
	unsigned long e820_checksum;
};
#define RESTORE_MAGIC 0x23456789ABCDEF02UL
#define NORM_SALT 0x48424658u /* keeps a normalised value from equalling a real one */

static struct e820_table **fw_table;
static struct e820_table **kern_table;

static u32 real_crc(const struct e820_table *t)
{
	size_t size = offsetof(struct e820_table, entries) +
		      sizeof(struct e820_entry) * t->nr_entries;

	return ~crc32_le(~0, (const unsigned char *)t, size);
}

struct norm_state {
	u32 crc;
	bool have;
	struct e820_entry cur;
};

static void emit(struct norm_state *s, u64 addr, u64 size, u32 type)
{
	if (!size)
		return;
	if (s->have && s->cur.type == type && s->cur.addr + s->cur.size == addr) {
		s->cur.size += size;
		return;
	}
	if (s->have)
		s->crc = crc32_le(s->crc, (const unsigned char *)&s->cur, sizeof(s->cur));
	s->cur.addr = addr;
	s->cur.size = size;
	s->cur.type = type;
	s->have = true;
}

/* crc of the firmware table with [win_start, win_end) collapsed to one ACPI entry */
static u32 norm_crc(const struct e820_table *t)
{
	struct norm_state s = { .crc = ~0u };
	bool inserted = false;
	u32 i;

	for (i = 0; i < t->nr_entries; i++) {
		const struct e820_entry *e = &t->entries[i];
		u64 start = e->addr, end = e->addr + e->size;

		if (end <= win_start) {
			emit(&s, start, e->size, e->type);
			continue;
		}
		if (start < win_start)
			emit(&s, start, win_start - start, e->type);
		if (!inserted && start < win_end) {
			emit(&s, win_start, win_end - win_start, E820_TYPE_ACPI);
			inserted = true;
		}
		if (end > win_end) {
			u64 from = start > win_end ? start : win_end;

			if (!inserted) {
				emit(&s, win_start, win_end - win_start, E820_TYPE_ACPI);
				inserted = true;
			}
			emit(&s, from, end - from, e->type);
		}
	}
	if (!inserted)
		emit(&s, win_start, win_end - win_start, E820_TYPE_ACPI);
	if (s.have)
		s.crc = crc32_le(s.crc, (const unsigned char *)&s.cur, sizeof(s.cur));
	return ~s.crc ^ NORM_SALT;
}

/*
 * Only normalise when it is safe: inside the window the firmware may report
 * nothing but RAM or ACPI reclaim, and the running kernel must not treat any
 * part of the window as RAM (i.e. the memmap= reservation is in effect).
 */
static bool window_safe(void)
{
	const struct e820_table *fw = *fw_table, *k = *kern_table;
	u32 i;

	for (i = 0; i < fw->nr_entries; i++) {
		const struct e820_entry *e = &fw->entries[i];

		if (e->addr < win_end && e->addr + e->size > win_start &&
		    e->type != E820_TYPE_RAM && e->type != E820_TYPE_ACPI)
			return false;
	}
	for (i = 0; i < k->nr_entries; i++) {
		const struct e820_entry *e = &k->entries[i];

		if (e->addr < win_end && e->addr + e->size > win_start &&
		    e->type == E820_TYPE_RAM)
			return false;
	}
	return true;
}

/* --- image kernel: store the normalised checksum --- */
static int save_entry(struct kretprobe_instance *ri, struct pt_regs *regs)
{
	*(void **)ri->data = (void *)regs->di;
	return 0;
}

static int save_ret(struct kretprobe_instance *ri, struct pt_regs *regs)
{
	struct restore_data_record *rdr = *(void **)ri->data;

	if (regs_return_value(regs) != 0)
		return 0;
	if (!window_safe()) {
		pr_warn("e820_hibfix: window not reserved; leaving strict checksum\n");
		return 0;
	}
	rdr->e820_checksum = norm_crc(*fw_table);
	pr_info("e820_hibfix: stored normalised e820 checksum %08lx\n", rdr->e820_checksum);
	return 0;
}

static struct kretprobe save_probe = {
	.kp.symbol_name = "arch_hibernation_header_save",
	.entry_handler = save_entry,
	.handler = save_ret,
	.data_size = sizeof(void *),
	.maxactive = 4,
};

/* --- restore kernel: accept a match of the normalised checksum --- */
static int restore_pre(struct kprobe *p, struct pt_regs *regs)
{
	struct restore_data_record *rdr = (void *)regs->di;
	u32 now;

	if (rdr->magic != RESTORE_MAGIC)
		return 0;
	if (!window_safe()) {
		pr_warn("e820_hibfix: window not reserved; strict check applies\n");
		return 0;
	}
	now = norm_crc(*fw_table);
	if (rdr->e820_checksum == now) {
		rdr->e820_checksum = real_crc(*fw_table);
		pr_info("e820_hibfix: e820 differs only inside %#lx-%#lx; allowing resume\n",
			win_start, win_end - 1);
	} else {
		pr_info("e820_hibfix: image %08lx != normalised %08x; strict check applies\n",
			rdr->e820_checksum, now);
	}
	return 0;
}

static struct kprobe restore_probe = {
	.symbol_name = "arch_hibernation_header_restore",
	.pre_handler = restore_pre,
};

/*
 * Resolve a (non-exported) data symbol. kallsyms_lookup_name() cannot be
 * called from a module here: with IBT sealing its endbr64 is removed, so an
 * indirect call faults. register_kprobe() resolves the name and stores the
 * address in kp.addr before rejecting the non-text address, so use that.
 */
static void *lookup_data(const char *name)
{
	struct kprobe kp = { .symbol_name = name };
	int ret = register_kprobe(&kp);

	if (ret == 0) { /* resolved to text: not what we want */
		unregister_kprobe(&kp);
		return NULL;
	}
	return kp.addr;
}

static bool table_sane(const struct e820_table *t)
{
	u32 i;

	if (!t || t->nr_entries == 0 || t->nr_entries > E820_MAX_ENTRIES)
		return false;
	for (i = 1; i < t->nr_entries; i++)
		if (t->entries[i].addr < t->entries[i - 1].addr + t->entries[i - 1].size)
			return false;
	return true;
}

static int __init hibfix_init(void)
{
	int ret;

	if (win_start >= win_end)
		return -EINVAL;
	fw_table = lookup_data("e820_table_firmware");
	kern_table = lookup_data("e820_table");
	if (!fw_table || !kern_table || fw_table == kern_table ||
	    !table_sane(*fw_table) || !table_sane(*kern_table)) {
		pr_err("e820_hibfix: e820 tables not found or implausible; not loading\n");
		return -ENOENT;
	}
	ret = register_kretprobe(&save_probe);
	if (ret)
		return ret;
	ret = register_kprobe(&restore_probe);
	if (ret) {
		unregister_kretprobe(&save_probe);
		return ret;
	}
	pr_info("e820_hibfix: loaded; window %#lx-%#lx safe=%d firmware crc %08x normalised %08x\n",
		win_start, win_end - 1, window_safe(), real_crc(*fw_table), norm_crc(*fw_table));
	return 0;
}

static void __exit hibfix_exit(void)
{
	unregister_kprobe(&restore_probe);
	unregister_kretprobe(&save_probe);
}

module_init(hibfix_init);
module_exit(hibfix_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Tolerate known firmware e820 drift when resuming from hibernation");
