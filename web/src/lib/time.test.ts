import { describe, expect, it } from "vitest";
import { formatAge, formatDuration, parseTimeInput, toTimeInput } from "./time";

describe("formatDuration", () => {
    it("formats hours and minutes", () => {
        expect(formatDuration(2.25)).toBe("2h 15m");
        expect(formatDuration(0.75)).toBe("45m");
        expect(formatDuration(3)).toBe("3h");
    });
});

describe("formatAge", () => {
    it("uses weeks for young babies, then months and years", () => {
        expect(formatAge(1)).toBe("1 week");
        expect(formatAge(6)).toBe("6 weeks");
        expect(formatAge(30.4)).toBe("7 months");
        expect(formatAge(52)).toBe("1 year");
        expect(formatAge(84.8)).toBe("1 year 8 months");
    });
});

describe("time inputs", () => {
    it("round-trips HH:MM", () => {
        expect(parseTimeInput("06:45")).toBe(6.75);
        expect(toTimeInput(6.75)).toBe("06:45");
        expect(toTimeInput(parseTimeInput("23:59")!)).toBe("23:59");
    });

    it("rejects invalid values", () => {
        expect(parseTimeInput("24:00")).toBeUndefined();
        expect(parseTimeInput("noon")).toBeUndefined();
    });
});
