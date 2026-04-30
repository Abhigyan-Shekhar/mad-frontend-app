import { createBrowserRouter } from "react-router";
import { Home } from "./components/Home";
import { PlanJourney } from "./components/PlanJourney";
import { SafetyScore } from "./components/SafetyScore";
import { GuardianMode } from "./components/GuardianMode";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: Home,
  },
  {
    path: "/plan-journey",
    Component: PlanJourney,
  },
  {
    path: "/safety-score",
    Component: SafetyScore,
  },
  {
    path: "/guardian-mode",
    Component: GuardianMode,
  },
]);
