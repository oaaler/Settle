<script lang="ts">
    import { onMount } from "svelte";
    import { api, type SimulatedDay, type Sweep } from "../api";
    import DayChart from "../charts/DayChart.svelte";
    import SweepChart, { type SweepSeries } from "../charts/SweepChart.svelte";
    import { formatAge, formatClock, formatDuration } from "../time";

    let ageWeeks = $state(30);
    let day = $state<SimulatedDay>();
    let sweep = $state<Sweep>();
    let error = $state<string>();

    $effect(() => {
        const age = ageWeeks;
        const controller = new AbortController();
        const timer = setTimeout(async () => {
            try {
                const { data, error: problem } = await api.GET("/v1/simulate/day", {
                    params: { query: { ageWeeks: age } },
                    signal: controller.signal,
                });
                if (data) {
                    day = data;
                    error = undefined;
                } else if (problem) error = problem.message;
            } catch (e) {
                if (!controller.signal.aborted) error = "Can't reach the sleep model API.";
            }
        }, 80);
        return () => {
            clearTimeout(timer);
            controller.abort();
        };
    });

    onMount(async () => {
        try {
            const { data } = await api.GET("/v1/simulate/sweep");
            sweep = data;
        } catch {
            error = "Can't reach the sleep model API.";
        }
    });

    const stageText: Record<string, string> = {
        newborn:
            "No body clock yet. Sleep comes in short bouts around the clock, driven by sleep pressure alone.",
        emerging: "The body clock is switching on (8–16 weeks), starting to pull sleep toward night.",
        established:
            "Body clock established. Sleep pressure and the clock together shape naps and night sleep.",
    };

    const ages = $derived(sweep?.points.map((p) => p.ageWeeks) ?? []);
    const pick = (f: (p: Sweep["points"][number]) => number | undefined) => sweep?.points.map(f) ?? [];
    const mean = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : undefined);

    const napSeries = $derived<SweepSeries[]>([
        { label: "Naps", slot: 1, values: pick((p) => p.summary.naps) },
    ]);
    const windowSeries = $derived<SweepSeries[]>([
        {
            label: "First",
            slot: 1,
            values: pick((p) => (p.summary.naps === undefined ? undefined : p.summary.wakeWindows[0])),
        },
        { label: "Average", slot: 2, dash: "5 3", values: pick((p) => mean(p.summary.wakeWindows)) },
        {
            label: "Before bed",
            slot: 3,
            dash: "2 3",
            values: pick((p) => (p.summary.naps === undefined ? undefined : p.summary.wakeWindows.at(-1))),
        },
    ]);
    const sleepSeries = $derived<SweepSeries[]>([
        { label: "Total", slot: 1, values: pick((p) => p.summary.totalSleepHours) },
        { label: "Night", slot: 2, dash: "5 3", values: pick((p) => p.summary.nightSleepHours) },
        { label: "Daytime", slot: 3, dash: "2 3", values: pick((p) => p.summary.daySleepHours) },
    ]);
    const hours = (v: number) => `${v.toFixed(v < 10 && v % 1 ? 1 : 0)}h`;
</script>

<section class="space-y-6">
    <div class="rounded-xl border border-line bg-surface-1 p-4 sm:p-6">
        <div class="flex flex-wrap items-end justify-between gap-4">
            <div>
                <h2 class="text-lg font-semibold">A simulated day</h2>
                <p class="mt-1 max-w-prose text-sm text-ink-2">
                    The model running on its own for several days at this age, with no parent setting nap
                    times. This is what the science implies, quirks included.
                </p>
            </div>
            <label class="block w-full sm:w-80">
                <span class="flex justify-between text-sm">
                    <span class="text-ink-2">Age</span>
                    <span class="font-semibold tabular">{formatAge(ageWeeks)}</span>
                </span>
                <input
                    type="range"
                    min="1"
                    max="104"
                    step="1"
                    bind:value={ageWeeks}
                    class="mt-2 w-full"
                    aria-label="Age in weeks"
                />
            </label>
        </div>

        {#if error}
            <p class="mt-4 rounded-md border border-line p-3 text-sm text-ink-2" role="alert">{error}</p>
        {/if}

        {#if day}
            <p class="mt-4 text-sm text-ink-2">{stageText[day.stage]}</p>
            <div class="mt-4">
                <DayChart
                    samples={day.samples}
                    bouts={day.bouts}
                    from={4}
                    to={28}
                    label="Sleep pressure and thresholds over a simulated day at {formatAge(ageWeeks)}"
                />
            </div>

            <dl class="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
                <div class="rounded-lg bg-surface-0 p-3">
                    <dt class="text-xs text-ink-3">Total sleep</dt>
                    <dd class="tabular text-xl font-semibold">
                        {formatDuration(day.summary.totalSleepHours)}
                    </dd>
                </div>
                <div class="rounded-lg bg-surface-0 p-3">
                    <dt class="text-xs text-ink-3">
                        {day.summary.naps === undefined ? "Sleeps per day" : "Naps"}
                    </dt>
                    <dd class="tabular text-xl font-semibold">
                        {day.summary.naps ?? day.summary.sleepBouts}
                    </dd>
                </div>
                <div class="rounded-lg bg-surface-0 p-3">
                    <dt class="text-xs text-ink-3">Night sleep</dt>
                    <dd class="tabular text-xl font-semibold">
                        {day.summary.nightSleepHours === undefined
                            ? "Not yet"
                            : formatDuration(day.summary.nightSleepHours)}
                    </dd>
                </div>
                <div class="rounded-lg bg-surface-0 p-3">
                    <dt class="text-xs text-ink-3">Morning wake → night sleep</dt>
                    <dd class="tabular text-xl font-semibold">
                        {#if day.summary.morningWake !== undefined && day.summary.nightSleepStart !== undefined}
                            {formatClock(day.summary.morningWake)} → {formatClock(
                                day.summary.nightSleepStart,
                            )}
                        {:else}
                            –
                        {/if}
                    </dd>
                </div>
            </dl>
            <p class="mt-3 text-sm text-ink-2">
                Wake windows:
                <span class="tabular">{day.summary.wakeWindows.map(formatDuration).join(" · ") || "–"}</span>
            </p>
        {/if}
    </div>

    <div class="rounded-xl border border-line bg-surface-1 p-4 sm:p-6">
        <h2 class="text-lg font-semibold">From birth to 2 years</h2>
        <p class="mt-1 max-w-prose text-sm text-ink-2">
            One model, one set of settings that change smoothly with age. Nap transitions are not programmed
            in; they fall out of sleep pressure building more slowly as the baby grows. The vertical line
            marks the age selected above ({formatAge(ageWeeks)}).
        </p>
        {#if sweep}
            <div class="mt-5 space-y-8">
                <SweepChart
                    title="Naps per day"
                    {ages}
                    series={napSeries}
                    format={(v) => String(v)}
                    marker={ageWeeks}
                    steps
                />
                <SweepChart
                    title="Wake windows"
                    {ages}
                    series={windowSeries}
                    format={hours}
                    marker={ageWeeks}
                />
                <SweepChart
                    title="Sleep per 24 hours"
                    {ages}
                    series={sleepSeries}
                    format={hours}
                    marker={ageWeeks}
                />
            </div>
            <details class="mt-6 text-sm">
                <summary class="cursor-pointer text-ink-2">Show as table</summary>
                <div class="mt-3 overflow-x-auto">
                    <table class="tabular w-full text-left text-xs">
                        <thead class="text-ink-3">
                            <tr
                                ><th class="py-1 pr-4">Age</th><th class="pr-4">Naps</th><th class="pr-4"
                                    >Wake windows</th
                                ><th class="pr-4">Total</th><th class="pr-4">Night</th><th>Daytime</th></tr
                            >
                        </thead>
                        <tbody>
                            {#each sweep.points.filter((p) => p.ageWeeks % 4 === 0) as p (p.ageWeeks)}
                                <tr class="border-t border-line">
                                    <td class="py-1 pr-4">{formatAge(p.ageWeeks)}</td>
                                    <td class="pr-4">{p.summary.naps ?? "–"}</td>
                                    <td class="pr-4"
                                        >{p.summary.wakeWindows.map(formatDuration).join(", ")}</td
                                    >
                                    <td class="pr-4">{formatDuration(p.summary.totalSleepHours)}</td>
                                    <td class="pr-4"
                                        >{p.summary.nightSleepHours === undefined
                                            ? "–"
                                            : formatDuration(p.summary.nightSleepHours)}</td
                                    >
                                    <td
                                        >{p.summary.daySleepHours === undefined
                                            ? "–"
                                            : formatDuration(p.summary.daySleepHours)}</td
                                    >
                                </tr>
                            {/each}
                        </tbody>
                    </table>
                </div>
            </details>
        {/if}
    </div>
</section>
