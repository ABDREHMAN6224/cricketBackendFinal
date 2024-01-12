import express from "express"
import { createCaptain, deleteCaptain, getAllCaptains, getSingleCaptain, updateCaptain } from "../controllers/captainController.js";
import { isAuthenticatedForTeam, isAuthenticatedForTeamInsertion } from "../middlewares/auth.js";
const router = express.Router();

router.get("/all", getAllCaptains);
router.get("/captain/:captainId", getSingleCaptain);
router.post("/createCaptain",isAuthenticatedForTeamInsertion,createCaptain);
router.put("/updateCaptain/:captainId",isAuthenticatedForTeam, updateCaptain);
router.delete("/captain/:captainId",isAuthenticatedForTeam, deleteCaptain);
export default router