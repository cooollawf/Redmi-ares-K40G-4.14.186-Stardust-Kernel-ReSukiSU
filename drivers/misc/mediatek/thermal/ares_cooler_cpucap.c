/*
 * Ares CPU frequency cap cooling device (MT6893)
 *
 * Used as the 2nd thermal stage: when the CPU zone crosses the "hard cap"
 * trip, PPM's hard user limit is set for every cluster so the SoC is pinned
 * to a low frequency instead of being throttled gradually by ATM.
 */

#ifdef pr_fmt
#undef pr_fmt
#endif
#define pr_fmt(fmt) "ares_cpucap: " fmt

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/printk.h>
#include <linux/types.h>

#include "mt-plat/mtk_thermal_monitor.h"

#define ARES_CAP_NUM_STATES	(1)
#define ARES_CAP_CLUSTERS	(3)
#define ARES_CAP_FREQ_KHZ	(1200000)

/* Mirrors struct ppm_limit_data; -1 means "no limit" */
struct ares_ppm_limit_data {
	int min;
	int max;
};

extern unsigned int mt_ppm_hard_userlimit_cpu_freq(unsigned int cluster_num,
						   void *data);

static struct thermal_cooling_device *ares_cap_dev;
static unsigned long ares_cap_level;

static int ares_cap_get_max_state(struct thermal_cooling_device *cdev,
				  unsigned long *state)
{
	*state = ARES_CAP_NUM_STATES;
	return 0;
}

static int ares_cap_get_cur_state(struct thermal_cooling_device *cdev,
				  unsigned long *state)
{
	*state = ares_cap_level;
	return 0;
}

static int ares_cap_set_cur_state(struct thermal_cooling_device *cdev,
				  unsigned long state)
{
	struct ares_ppm_limit_data data[ARES_CAP_CLUSTERS];
	unsigned int ret;
	int i;

	if (state > ARES_CAP_NUM_STATES)
		return -EINVAL;

	/* the thermal core re-applies the state every 200 ms; stay quiet */
	if (state == ares_cap_level)
		return 0;

	for (i = 0; i < ARES_CAP_CLUSTERS; i++) {
		data[i].min = -1;
		data[i].max = state ? ARES_CAP_FREQ_KHZ : -1;
	}

	ret = mt_ppm_hard_userlimit_cpu_freq(ARES_CAP_CLUSTERS, data);
	if (ret)
		pr_info("set cap state %lu failed: %u\n", state, ret);
	else
		pr_info("cpu cap %s (%d kHz)\n",
			state ? "ON" : "OFF", state ? ARES_CAP_FREQ_KHZ : -1);

	ares_cap_level = state;
	return 0;
}

static struct thermal_cooling_device_ops ares_cap_ops = {
	.get_max_state = ares_cap_get_max_state,
	.get_cur_state = ares_cap_get_cur_state,
	.set_cur_state = ares_cap_set_cur_state,
};

static int __init ares_cpucap_init(void)
{
	ares_cap_dev = mtk_thermal_cooling_device_register("ares_cpu_cap", NULL,
							  &ares_cap_ops);
	if (!ares_cap_dev) {
		pr_info("register cooling device failed\n");
		return -ENODEV;
	}

	pr_info("registered, cap frequency %d kHz\n", ARES_CAP_FREQ_KHZ);
	return 0;
}

static void __exit ares_cpucap_exit(void)
{
	if (ares_cap_dev) {
		mtk_thermal_cooling_device_unregister(ares_cap_dev);
		ares_cap_dev = NULL;
	}
}

module_init(ares_cpucap_init);
module_exit(ares_cpucap_exit);
