import { describe, expect, it } from "vitest";
import { linear, linePath, spreadLabels, stepPath } from "./scale";

describe("linear", () => {
    it("maps and inverts", () => {
        const x = linear([0, 10], [100, 200]);
        expect(x(5)).toBe(150);
        expect(x.invert(150)).toBe(5);
    });
});

describe("paths", () => {
    it("breaks lines on missing values", () => {
        expect(
            linePath([
                [0, 1],
                [1, undefined],
                [2, 3],
                [3, 4],
            ]),
        ).toBe("M0.0,1.0M2.0,3.0L3.0,4.0");
    });

    it("draws steps", () => {
        expect(
            stepPath([
                [0, 3],
                [1, 3],
                [2, 2],
            ]),
        ).toBe("M0.0,3.0H1.0V3.0H2.0V2.0");
    });
});

describe("spreadLabels", () => {
    it("keeps labels at least `gap` apart and preserves order", () => {
        expect(spreadLabels([100, 105, 300], 13)).toEqual([100, 113, 300]);
        expect(spreadLabels([50, 40], 13)).toEqual([53, 40]);
    });
});
