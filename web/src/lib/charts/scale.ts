/** Minimal linear scale. */
export function linear(domain: [number, number], range: [number, number]) {
    const [d0, d1] = domain;
    const [r0, r1] = range;
    const k = d1 === d0 ? 0 : (r1 - r0) / (d1 - d0);
    const scale = (v: number) => r0 + (v - d0) * k;
    scale.invert = (p: number) => (k === 0 ? d0 : d0 + (p - r0) / k);
    return scale;
}

/** SVG path through points; `undefined` y values break the line. */
export function linePath(points: [number, number | undefined][]): string {
    let d = "";
    let pen = false;
    for (const [x, y] of points) {
        if (y === undefined || Number.isNaN(y)) {
            pen = false;
            continue;
        }
        d += `${pen ? "L" : "M"}${x.toFixed(1)},${y.toFixed(1)}`;
        pen = true;
    }
    return d;
}

/** Step path (horizontal then vertical) for integer series like naps per day. */
export function stepPath(points: [number, number | undefined][]): string {
    let d = "";
    let prev: [number, number] | undefined;
    for (const [x, y] of points) {
        if (y === undefined) {
            prev = undefined;
            continue;
        }
        if (!prev) d += `M${x.toFixed(1)},${y.toFixed(1)}`;
        else d += `H${x.toFixed(1)}V${y.toFixed(1)}`;
        prev = [x, y];
    }
    return d;
}

/**
 * Nudges direct labels apart vertically so none are closer than `gap` px, keeping their order.
 * Returns adjusted y positions in the input order.
 */
export function spreadLabels(ys: number[], gap = 13): number[] {
    const order = ys.map((y, i) => ({ y, i })).sort((a, b) => a.y - b.y);
    for (let k = 1; k < order.length; k++) {
        const prev = order[k - 1]!;
        const cur = order[k]!;
        if (cur.y - prev.y < gap) cur.y = prev.y + gap;
    }
    const out = new Array<number>(ys.length);
    for (const { y, i } of order) out[i] = y;
    return out;
}
