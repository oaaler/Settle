/** Clock hours (hours since midnight of the sleep day, may exceed 24) ↔ display strings. */

const clock = new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" });

export function hourToDate(hour: number): Date {
    // A fixed date without DST changes; only the time of day is displayed.
    return new Date(2026, 0, 15, 0, Math.round(hour * 60));
}

/** "6:45 AM" or "06:45", following the visitor's locale. */
export function formatClock(hour: number): string {
    return clock.format(hourToDate(hour));
}

/** "2h 15m", "45m", "3h". */
export function formatDuration(hours: number): string {
    const minutes = Math.round(hours * 60);
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    if (h === 0) return `${m}m`;
    return m === 0 ? `${h}h` : `${h}h ${m}m`;
}

const WEEKS_PER_MONTH = 52 / 12;

export function weeksToMonths(weeks: number): number {
    return weeks / WEEKS_PER_MONTH;
}

export function monthsToWeeks(months: number): number {
    return months * WEEKS_PER_MONTH;
}

/** "3 weeks" under 3 months, then "7 months", "1 year 2 months". */
export function formatAge(weeks: number): string {
    if (weeks < 13) {
        const w = Math.round(weeks);
        return `${w} week${w === 1 ? "" : "s"}`;
    }
    const months = Math.round(weeksToMonths(weeks));
    if (months < 12) return `${months} months`;
    const years = Math.floor(months / 12);
    const rest = months % 12;
    const y = `${years} year${years === 1 ? "" : "s"}`;
    return rest === 0 ? y : `${y} ${rest} month${rest === 1 ? "" : "s"}`;
}

/** "HH:MM" from an <input type="time"> → clock hour. */
export function parseTimeInput(value: string): number | undefined {
    const match = /^(\d{1,2}):(\d{2})$/.exec(value);
    if (!match) return undefined;
    const h = Number(match[1]);
    const m = Number(match[2]);
    if (h > 23 || m > 59) return undefined;
    return h + m / 60;
}

/** Clock hour → "HH:MM" for an <input type="time">. */
export function toTimeInput(hour: number): string {
    const minutes = Math.round(hour * 60) % (24 * 60);
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}
