<script lang="ts" module>
    export interface SweepSeries {
        label: string;
        slot: 1 | 2 | 3;
        values: (number | undefined)[];
        dash?: string;
    }
</script>

<script lang="ts">
    import { formatAge, monthsToWeeks } from "../time";
    import { linear, linePath, spreadLabels, stepPath } from "./scale";

    interface Props {
        title: string;
        ages: number[];
        series: SweepSeries[];
        format: (v: number) => string;
        /** Selected age (weeks), drawn as a marker. */
        marker?: number;
        steps?: boolean;
        yMin?: number;
    }

    let { title, ages, series, format, marker, steps = false, yMin = 0 }: Props = $props();

    const height = 200;
    const margin = { top: 12, right: 84, bottom: 28, left: 40 };
    let width = $state(640);

    const yMax = $derived(
        Math.max(...series.flatMap((s) => s.values.filter((v): v is number => v !== undefined)), 1),
    );
    const x = $derived(linear([0, 104], [margin.left, width - margin.right]));
    const y = $derived(linear([yMin, Math.ceil(yMax)], [height - margin.bottom, margin.top]));
    const yTicks = $derived.by(() => {
        const top = Math.ceil(yMax);
        const step = top > 12 ? 4 : top > 6 ? 2 : 1;
        const out: number[] = [];
        for (let v = yMin; v <= top; v += step) out.push(v);
        return out;
    });
    // Every 3, 6 or 12 months, whichever leaves room (~44px) for a label at this width.
    const monthTicks = $derived.by(() => {
        const pxPerMonth = (width - margin.left - margin.right) / 24;
        const step = [3, 6, 12].find((m) => m * pxPerMonth >= 44) ?? 12;
        return Array.from({ length: 24 / step + 1 }, (_, i) => i * step);
    });

    const toPath = (s: SweepSeries) =>
        (steps ? stepPath : linePath)(
            ages.map((a, i) => [x(a), s.values[i] === undefined ? undefined : y(s.values[i]!)]),
        );

    function lastValue(s: SweepSeries): number | undefined {
        for (let i = s.values.length - 1; i >= 0; i--) if (s.values[i] !== undefined) return s.values[i];
        return undefined;
    }

    // Direct labels at each series' last value, nudged apart so they never overlap.
    const labelYs = $derived.by(() => {
        const ends = series.map((s) => lastValue(s));
        const placed = spreadLabels(ends.map((v) => (v === undefined ? -1e6 : y(v))));
        return ends.map((v, i) => (v === undefined ? undefined : placed[i]));
    });

    let hoverIndex = $state<number | undefined>();
    function onMove(event: PointerEvent) {
        const box = (event.currentTarget as SVGRectElement).ownerSVGElement!.getBoundingClientRect();
        const age = x.invert(event.clientX - box.left);
        let best = 0;
        ages.forEach((a, i) => {
            if (Math.abs(a - age) < Math.abs(ages[best]! - age)) best = i;
        });
        hoverIndex = best;
    }
</script>

<figure class="m-0">
    <div class="mb-1 flex flex-wrap items-baseline justify-between gap-2">
        <h3 class="text-sm font-semibold text-ink">{title}</h3>
        {#if series.length > 1}
            <div class="flex flex-wrap gap-x-3 text-xs text-ink-2">
                {#each series as s (s.label)}
                    <span class="inline-flex items-center gap-1.5">
                        <svg width="16" height="8" aria-hidden="true"
                            ><line
                                x1="0"
                                x2="16"
                                y1="4"
                                y2="4"
                                stroke="var(--series-{s.slot})"
                                stroke-width="2"
                                stroke-dasharray={s.dash}
                            /></svg
                        >
                        {s.label}
                    </span>
                {/each}
            </div>
        {/if}
    </div>
    <div class="relative" bind:clientWidth={width}>
        <svg
            {width}
            {height}
            role="img"
            aria-label="{title} by age, 0 to 24 months"
            class="block overflow-visible"
        >
            {#each yTicks as v (v)}
                <line x1={margin.left} x2={width - margin.right} y1={y(v)} y2={y(v)} stroke="var(--grid)" />
                <text
                    x={margin.left - 6}
                    y={y(v) + 4}
                    text-anchor="end"
                    class="tabular fill-ink-3 text-[11px]">{format(v)}</text
                >
            {/each}
            {#each monthTicks as m (m)}
                <text
                    x={x(monthsToWeeks(m))}
                    y={height - 8}
                    text-anchor="middle"
                    class="fill-ink-3 text-[11px]">{m === 0 ? "birth" : `${m} mo`}</text
                >
            {/each}

            {#if marker !== undefined}
                <line
                    x1={x(marker)}
                    x2={x(marker)}
                    y1={margin.top}
                    y2={height - margin.bottom}
                    stroke="var(--accent)"
                    stroke-width="1.5"
                />
            {/if}

            {#each series as s, i (s.label)}
                {@const labelY = labelYs[i]}
                <path
                    d={toPath(s)}
                    fill="none"
                    stroke="var(--series-{s.slot})"
                    stroke-width="2"
                    stroke-dasharray={s.dash}
                    stroke-linejoin="round"
                />
                {#if labelY !== undefined}
                    <text x={width - margin.right + 8} y={labelY + 4} class="fill-ink-2 text-[11px]"
                        >{s.label}</text
                    >
                {/if}
            {/each}

            {#if hoverIndex !== undefined}
                <line
                    x1={x(ages[hoverIndex]!)}
                    x2={x(ages[hoverIndex]!)}
                    y1={margin.top}
                    y2={height - margin.bottom}
                    stroke="var(--text-muted)"
                    stroke-dasharray="2 2"
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
                onpointerleave={() => (hoverIndex = undefined)}
            />
        </svg>

        {#if hoverIndex !== undefined}
            <div
                class="pointer-events-none absolute z-10 rounded-md border border-line bg-surface-1 px-2.5 py-1.5 text-xs shadow-sm"
                style="left: {Math.min(x(ages[hoverIndex]!) + 12, width - 160)}px; top: {margin.top}px"
            >
                <div class="font-medium text-ink">{formatAge(ages[hoverIndex]!)}</div>
                {#each series as s (s.label)}
                    {@const v = s.values[hoverIndex]}
                    <div class="tabular text-ink-2">{s.label}: {v === undefined ? "–" : format(v)}</div>
                {/each}
            </div>
        {/if}
    </div>
</figure>
