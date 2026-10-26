import createClient from "openapi-fetch";
import type { components, paths } from "./api-schema";

/** Typed client generated from Server/Sources/SettleAPI/openapi.yaml. Same origin; nginx/Vite forward /api. */
export const api = createClient<paths>({ baseUrl: "/api" });

type Schemas = components["schemas"];
export type SimulatedDay = Schemas["SimulatedDay"];
export type Sweep = Schemas["Sweep"];
export type DaySummary = Schemas["DaySummary"];
export type DayPlan = Schemas["DayPlan"];
export type DayPlanRequest = Schemas["DayPlanRequest"];
export type PressureSample = Schemas["PressureSample"];
export type SleepBout = Schemas["SleepBout"];
export type SleepWindow = Schemas["SleepWindow"];
export type Reason = Schemas["Reason"];
export type Problem = Schemas["Problem"];
