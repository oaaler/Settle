<script lang="ts">
    import type { PressureSample, SleepBout, SleepWindow } from "../api";
    import { formatClock } from "../time";
    import { linear, linePath, spreadLabels } from "./scale";

    interface Props {
        samples: PressureSample[];
        bouts: SleepBout[];
        /** Hour domain to draw. */
        from: number;
        to: number;
        /** Samples after this hour are the day plan (drawn dashed). */
        now?: number;
        sleepWindow?: SleepWindow;
        label: string;
    }

    let { samples, bouts, from, to, now, sleepWindow, label }: Props = $props();

    const height = 280;
    const margin = { top: 20, right: 104, bottom: 30, left: 36 };
    let width = $state(640);

    const x = $derived(linear([from, to], [margin.left, width - margin.right]));
    const y = $derived(linear([0, 1], [height - margin.bottom, margin.top]));

    const ticks = $derived.by(() => {
        // Smallest step that leaves room for a time label (~56px) at the current width.
        const pxPerHour = (width - margin.left - margin.right) / (to - from);
        const step = [1, 2, 3, 4, 6, 8, 12].find((h) => h * pxPerHour >= 56) ?? 12;
        const out: number[] = [];
        for (let h = Math.ceil(from / step) * step; h <= to + 1e-9; h += step) out.push(h);
        return out;
    });

    const past = $derived(now === undefined ? samples : samples.filter((s) => s.hour <= now + 1e-9));
    const planned = $derived(now === undefined ? [] : samples.filter((s) => s.hour >= now - 1e-9));
    const path = (rows: PressureSample[], key: "pressure" | "upper" | "lower") =>
        linePath(rows.map((s) => [x(s.hour), y(s[key])]));

    const last = $derived(samples.at(-1));

    // Hover: nearest sample to the pointer.
    let hover = $state<PressureSample | undefined>();
    function onMove(event: PointerEvent) {
        const svg = event.currentTarget as SVGRectElement;
        const box = svg.ownerSVGElement!.getBoundingClientRect();
        const hour = x.invert(event.clientX - box.left);
        let best: PressureSample | undefined;
        for (const s of samples) if (!best || Math.abs(s.hour - hour) < Math.abs(best.hour - hour)) best = s;
        hover = best;
    }
</script>

<figure class="m-0">
    <figcaption class="mb-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-ink-2">
        <span class="inline-flex items-center gap-1.5">
            <svg width="18" height="8" aria-hidden="true"
                ><line x1="0" x2="18" y1="4" y2="4" stroke="var(--series-1)" stroke-width="2" /></svg
            >
            Sleep pressure
        </span>
        <span class="inline-flex items-center gap-1.5">
            <svg width="18" height="8" aria-hidden="true"
                ><line
                    x1="0"
                    x2="18"
                    y1="4"
                    y2="4"
                    stroke="var(--series-2)"
                    stroke-width="2"
                    stroke-dasharray="5 3"
                /></svg
            >
            Falls asleep at
        </span>
        <span class="inline-flex items-center gap-1.5">
            <svg width="18" height="8" aria-hidden="true"
                ><line
                    x1="0"
                    x2="18"
                    y1="4"
                    y2="4"
                    stroke="var(--series-3)"
                    stroke-width="2"
                    stroke-dasharray="2 3"
                /></svg
            >
            Wakes at
        </span>
        <span class="inline-flex items-center gap-1.5">
            <span class="inline-block h-3 w-4 rounded-sm" style="background: var(--sleep-fill)"></span>
            Asleep
        </span>
        {#if now !== undefined}
            <span class="inline-flex items-center gap-1.5">
                <svg width="18" height="8" aria-hidden="true"
                    ><line
                        x1="0"
                        x2="18"
                        y1="4"
                        y2="4"
                        stroke="var(--series-1)"
                        stroke-width="2"
                        stroke-dasharray="4 4"
                        opacity="0.7"
                    /></svg
                >
                Day plan
            </span>
        {/if}
    </figcaption>

    <div class="relative" bind:clientWidth={width}>
        <svg {width} {height} role="img" aria-label={label} class="block overflow-visible">
            <!-- grid -->
            {#each [0, 0.25, 0.5, 0.75, 1] as v (v)}
                <line x1={margin.left} x2={width - margin.right} y1={y(v)} y2={y(v)} stroke="var(--grid)" />
            {/each}
            <text x={margin.left - 6} y={y(1) + 4} text-anchor="end" class="fill-ink-3 text-[11px]">high</text
            >
            <text x={margin.left - 6} y={y(0) + 4} text-anchor="end" class="fill-ink-3 text-[11px]">low</text>

            <!-- sleep (2px surface gap between adjacent spans) -->
            {#each bouts as b (b.start)}
                {@const x0 = x(Math.max(b.start, from))}
                {@const x1 = x(Math.min(b.end, to))}
                {#if x1 > x0}
                    <rect
                        x={x0 + 1}
                        y={margin.top}
                        width={Math.max(0, x1 - x0 - 2)}
                        height={height - margin.top - margin.bottom}
                        rx="4"
                        fill="var(--sleep-fill)"
                    />
                {/if}
            {/each}

            {#if sleepWindow}
                <rect
                    x={x(sleepWindow.earliest)}
                    y={margin.top}
                    width={Math.max(2, x(sleepWindow.latest) - x(sleepWindow.earliest))}
                    height={height - margin.top - margin.bottom}
                    fill="var(--window-fill)"
                    stroke="var(--series-1)"
                    stroke-width="1"
                    rx="2"
                />
                <text
                    x={x(sleepWindow.target)}
                    y={margin.top - 6}
                    text-anchor="middle"
                    class="fill-ink-2 text-[11px] font-medium">Sleep window</text
                >
            {/if}

            <!-- thresholds -->
            <path
                d={path(samples, "upper")}
                fill="none"
                stroke="var(--series-2)"
                stroke-width="2"
                stroke-dasharray="5 3"
            />
            <path
                d={path(samples, "lower")}
                fill="none"
                stroke="var(--series-3)"
                stroke-width="2"
                stroke-dasharray="2 3"
            />

            <!-- pressure: logged solid, day plan dashed -->
            <path
                d={path(past, "pressure")}
                fill="none"
                stroke="var(--series-1)"
                stroke-width="2"
                stroke-linejoin="round"
            />
            {#if planned.length}
                <path
                    d={path(planned, "pressure")}
                    fill="none"
                    stroke="var(--series-1)"
                    stroke-width="2"
                    stroke-dasharray="4 4"
                    opacity="0.7"
                />
            {/if}

            {#if now !== undefined}
                <line
                    x1={x(now)}
                    x2={x(now)}
                    y1={margin.top}
                    y2={height - margin.bottom}
                    stroke="var(--text-secondary)"
                    stroke-width="1.5"
                />
                <text x={x(now) + 4} y={height - margin.bottom - 6} class="fill-ink-2 text-[11px] font-medium"
                    >Now</text
                >
            {/if}

            <!-- direct labels at the right edge -->
            {#if last}
                {@const [yP, yU, yL] = spreadLabels([y(last.pressure), y(last.upper), y(last.lower)])}
                <text x={width - margin.right + 8} y={yP! + 4} class="fill-ink text-[11px]">Pressure</text>
                <text x={width - margin.right + 8} y={yU! + 4} class="fill-ink-2 text-[11px]"
                    >Falls asleep</text
                >
                <text x={width - margin.right + 8} y={yL! + 4} class="fill-ink-2 text-[11px]">Wakes</text>
            {/if}

            <!-- x axis -->
            {#each ticks as h (h)}
                <text x={x(h)} y={height - 8} text-anchor="middle" class="fill-ink-3 text-[11px]"
                    >{formatClock(h)}</text
                >
            {/each}

            {#if hover}
                <line
                    x1={x(hover.hour)}
                    x2={x(hover.hour)}
                    y1={margin.top}
                    y2={height - margin.bottom}
                    stroke="var(--text-muted)"
                    stroke-dasharray="2 2"
                />
                <circle
                    cx={x(hover.hour)}
                    cy={y(hover.pressure)}
                    r="4"
                    fill="var(--series-1)"
                    stroke="var(--surface-1)"
                    stroke-width="2"
                />
            {/if}

            <rect
                x={margin.left}
                y={margin.top}
                width={Math.max(0, width - margin.left - margin.right)}
                height={height - margin.top - margin.bottom}
                fill="transparent"
                role="presentation"
                onpointermove={onMove}
                onpointerleave={() => (hover = undefined)}
            />
        </svg>

        {#if hover}
            <div
                class="pointer-events-none absolute z-10 rounded-md border border-line bg-surface-1 px-2.5 py-1.5 text-xs shadow-sm"
                style="left: {Math.min(x(hover.hour) + 12, width - 150)}px; top: {margin.top}px"
            >
                <div class="font-medium text-ink">
                    {formatClock(hover.hour)} · {hover.asleep ? "asleep" : "awake"}
                </div>
                <div class="tabular text-ink-2">Pressure {(hover.pressure * 100).toFixed(0)}%</div>
                <div class="tabular text-ink-3">
                    Falls asleep at {(hover.upper * 100).toFixed(0)}% · wakes at {(hover.lower * 100).toFixed(
                        0,
                    )}%
                </div>
            </div>
        {/if}
    </div>
</figure>
