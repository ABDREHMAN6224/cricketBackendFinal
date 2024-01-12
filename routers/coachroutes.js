import express from "express"
import { createCoach, deleteCoach, getAllCoaches, modifyCoach } from "../controllers/coachController.js";
import { isAuthenticatedForTeam, isAuthenticatedForTeamInsertion } from "../middlewares/auth.js";
const router = express.Router();
router.get("/all", getAllCoaches);
router.post("/coach",isAuthenticatedForTeamInsertion, createCoach);
router.delete("/coach/:coachId",isAuthenticatedForTeam, deleteCoach);
router.put("/coach/:coachId",isAuthenticatedForTeam, modifyCoach);
export default router;