<script lang="ts">
    import { api, type DayPlan, type DayPlanRequest, type Reason } from "../api";
    import DayChart from "../charts/DayChart.svelte";
    import { formatAge, formatClock, formatDuration, parseTimeInput, toTimeInput } from "../time";

    interface NapInput {
        id: number;
        start: string;
        end: string;
        inProgress: boolean;
    }

    let ageWeeks = $state(30);
    let morningWake = $state("06:45");
    let nextId = 2;
    let naps = $state<NapInput[]>([{ id: 1, start: "09:00", end: "10:15", inProgress: false }]);
    let now = $state(11);

    let result = $state<DayPlan>();
    let problem = $state<string>();

    const wakeHour = $derived(parseTimeInput(morningWake) ?? 7);
    // Keep "now" within the day as the morning wake moves.
    $effect(() => {
        if (now < wakeHour) now = wakeHour;
    });

    const request = $derived.by((): DayPlanRequest | string => {
        const parsed = [];
        for (const [i, nap] of naps.entries()) {
            const start = parseTimeInput(nap.start);
            const end = nap.inProgress ? undefined : parseTimeInput(nap.end);
            if (start === undefined || (!nap.inProgress && end === undefined))
                return `Nap ${i + 1} needs a start and end time.`;
            parsed.push(end === undefined ? { start } : { start, end });
        }
        return { ageWeeks, morningWake: wakeHour, naps: parsed, now };
    });

    $effect(() => {
        const body = request;
        if (typeof body === "string") {
            problem = body;
            return;
        }
        const controller = new AbortController();
        const timer = setTimeout(async () => {
            try {
                const { data, error } = await api.POST("/v1/day-plan", { body, signal: controller.signal });
                if (data) {
                    result = data;
                    problem = undefined;
                } else if (error) problem = error.message;
            } catch {
                if (!controller.signal.aborted) problem = "Can't reach the sleep model API.";
            }
        }, 80);
        return () => {
            clearTimeout(timer);
            controller.abort();
        };
    });

    function addNap() {
        const lastEnd = parseTimeInput(naps.at(-1)?.end ?? morningWake) ?? wakeHour;
        const start = Math.min(lastEnd + 2.5, now);
        naps.push({
            id: nextId++,
            start: toTimeInput(start),
            end: toTimeInput(Math.min(start + 1, now)),
            inProgress: false,
        });
    }

    function reasonText(r: Reason): string {
        switch (r.kind) {
            case "shortLastSleep":
                return `Last nap was short (${r.minutes ?? "?"} min), so pressure is still high → shorter wake window.`;
            case "longLastSleep":
                return `Last nap was long (${formatDuration((r.minutes ?? 0) / 60)}), so pressure drained further → longer wake window.`;
            case "eveningClock":
                return "Evening: the body clock is lowering the fall-asleep threshold, pulling bedtime in.";
        }
    }

    const nightStart = $derived(result?.plan.find((p) => p.kind === "night")?.start);
    const bouts = $derived.by(() => {
        if (!result) return [];
        const logged = naps
            .map((n) => ({
                start: parseTimeInput(n.start)!,
                end: n.inProgress ? now : parseTimeInput(n.end)!,
            }))
            .filter((b) => b.start !== undefined && b.end !== undefined);
        const planned = result.plan.map((p) => ({
            start: p.start,
            end: p.end ?? (nightStart ?? p.start) + 1.5,
        }));
        return [...logged, ...planned];
    });
</script>

<section class="grid gap-6 lg:grid-cols-[22rem_1fr]">
    <form
        class="space-y-5 rounded-xl border border-line bg-surface-1 p-4 sm:p-6"
        onsubmit={(e) => e.preventDefault()}
    >
        <div>
            <h2 class="text-lg font-semibold">Today so far</h2>
            <p class="mt-1 text-sm text-ink-2">
                Enter a day, then drag <em>Now</em> to watch the sleep window and day plan update.
            </p>
        </div>

        <label class="block">
            <span class="flex justify-between text-sm">
                <span class="text-ink-2">Age</span><span class="font-semibold tabular"
                    >{formatAge(ageWeeks)}</span
                >
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

        <label class="flex items-center justify-between gap-3 text-sm">
            <span class="text-ink-2">Morning wake</span>
            <input
                type="time"
                bind:value={morningWake}
                class="rounded-md border border-line bg-surface-0 px-2 py-1"
            />
        </label>

        <fieldset class="space-y-2">
            <legend class="text-sm text-ink-2">Naps today</legend>
            {#each naps as nap, i (nap.id)}
                <div class="flex flex-wrap items-center gap-2 rounded-lg bg-surface-0 p-2 text-sm">
                    <span class="w-12 text-ink-3">Nap {i + 1}</span>
                    <input
                        type="time"
                        bind:value={nap.start}
                        aria-label="Nap {i + 1} start"
                        class="rounded-md border border-line bg-surface-1 px-2 py-1"
                    />
                    {#if nap.inProgress}
                        <span class="text-ink-2">asleep now</span>
                    {:else}
                        <span class="text-ink-3">–</span>
                        <input
                            type="time"
                            bind:value={nap.end}
                            aria-label="Nap {i + 1} end"
                            class="rounded-md border border-line bg-surface-1 px-2 py-1"
                        />
                    {/if}
                    {#if i === naps.length - 1}
                        <label class="ml-auto flex items-center gap-1 text-xs text-ink-2">
                            <input type="checkbox" bind:checked={nap.inProgress} /> in progress
                        </label>
                    {/if}
                    <button
                        type="button"
                        class="text-xs text-ink-3 underline"
                        onclick={() => naps.splice(i, 1)}>remove</button
                    >
                </div>
            {/each}
            <button type="button" class="rounded-md border border-line px-3 py-1 text-sm" onclick={addNap}
                >Add nap</button
            >
        </fieldset>

        <label class="block">
            <span class="flex justify-between text-sm">
                <span class="text-ink-2">Now</span><span class="font-semibold tabular"
                    >{formatClock(now)}</span
                >
            </span>
            <input
                type="range"
                min={wakeHour}
                max={23.99}
                step={5 / 60}
                bind:value={now}
                class="mt-2 w-full"
                aria-label="Current time"
            />
        </label>
    </form>

    <div class="space-y-4 rounded-xl border border-line bg-surface-1 p-4 sm:p-6">
        {#if problem}
            <p class="rounded-md border border-line p-3 text-sm text-ink-2" role="alert">{problem}</p>
        {/if}

        {#if result}
            <div class="grid gap-3 sm:grid-cols-2">
                <div class="rounded-lg bg-surface-0 p-4">
                    {#if result.asleepNow}
                        <div class="text-xs text-ink-3">Asleep now · predicted to wake</div>
                        <div class="tabular text-2xl font-semibold">
                            {result.plan[0]?.end !== undefined ? formatClock(result.plan[0].end) : "–"}
                        </div>
                    {:else if result.sleepWindow}
                        <div class="text-xs text-ink-3">Sleep window</div>
                        <div class="tabular text-2xl font-semibold">
                            {formatClock(result.sleepWindow.earliest)} – {formatClock(
                                result.sleepWindow.latest,
                            )}
                        </div>
                        <div class="mt-1 text-xs text-ink-2">
                            in {formatDuration(result.sleepWindow.target - now)}
                        </div>
                    {/if}
                </div>
                <div class="rounded-lg bg-surface-0 p-4">
                    <div class="text-xs text-ink-3">Sleep pressure now</div>
                    <div class="tabular text-2xl font-semibold">{(result.pressureNow * 100).toFixed(0)}%</div>
                    <div class="mt-1 text-xs text-ink-2">
                        falls asleep around {(
                            (result.samples.find((s) => s.hour >= now)?.upper ?? 0) * 100
                        ).toFixed(0)}%
                    </div>
                </div>
            </div>

            {#if result.reasons.length}
                <ul class="space-y-1 text-sm text-ink-2">
                    {#each result.reasons as r (r.kind)}
                        <li>{reasonText(r)}</li>
                    {/each}
                </ul>
            {/if}

            <DayChart
                samples={result.samples}
                {bouts}
                from={wakeHour}
                to={(nightStart ?? now) + 1.5}
                {now}
                sleepWindow={result.sleepWindow}
                label="Sleep pressure from morning wake, with the day plan after now"
            />

            <div>
                <h3 class="text-sm font-semibold">Day plan</h3>
                <ol class="mt-2 space-y-1 text-sm">
                    {#each result.plan as p, i (i)}
                        <li class="tabular flex gap-3">
                            <span class="w-24 text-ink-3"
                                >{p.kind === "night"
                                    ? "Night sleep"
                                    : p.inProgress
                                      ? "This nap"
                                      : "Nap"}</span
                            >
                            <span>
                                {#if p.inProgress}
                                    wakes ~{formatClock(p.end ?? p.start)}
                                {:else if p.kind === "night"}
                                    from ~{formatClock(p.start)}
                                {:else}
                                    ~{formatClock(p.start)} – {formatClock(p.end ?? p.start)}
                                    <span class="text-ink-3"
                                        >({formatDuration((p.end ?? p.start) - p.start)})</span
                                    >
                                {/if}
                            </span>
                        </li>
                    {/each}
                </ol>
                <p class="mt-3 text-xs text-ink-3">
                    Planned nap lengths are where the model's sleep pressure naturally drains, not typical
                    lengths for the age.
                </p>
            </div>
        {/if}
    </div>
</section>
