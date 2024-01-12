import express from "express"
import { appointCaptain, appointCoach, appointWicketKeeper, createTeam, deleteTeam, getAllTeams, getTeamById, getTeamMatches, getTeamPlayers, getTeamPlayersSquad, getWonTournameents, updatePlayerTeam, updateTeam } from "../controllers/teamController.js"
import { isAuthenticatedForTeam, isAuthenticatedForTeamInsertion } from "../middlewares/auth.js"
const router = express.Router()

router.post("/appointCoach/:teamId",isAuthenticatedForTeam, appointCoach)
router.post("/appointCaptain/:teamId",isAuthenticatedForTeam, appointCaptain)
router.get("/getTeamPlayers/:teamId", getTeamPlayers)
router.post("/createTeam",isAuthenticatedForTeamInsertion, createTeam);
router.get("/all", getAllTeams)
router.delete("/team/:teamId",isAuthenticatedForTeam, deleteTeam)
router.get("/team/:teamId", getTeamById)
router.put("/updateTeam/:teamId",isAuthenticatedForTeam, updateTeam)
router.get("/tournamentWon/:teamId", getWonTournameents)
router.post("/appointWicketKeeper/:teamId",isAuthenticatedForTeam, appointWicketKeeper)
router.post("/updatePlayerTeam/:teamId/:playerId",isAuthenticatedForTeam, updatePlayerTeam)
router.get("/teamSquad/:teamId", getTeamPlayersSquad)
router.get("/teamMatches/:teamId",getTeamMatches)
export default router