import express from "express"
import { createMatch, deleteMatch, getAllMatches, getMatchesByLocation, getMatchesByTeam, getMatchesByTournament, getMatchesByTwoTeams, getSingleMatch, updateMatch } from "../controllers/matchController.js";
import { isAuthenticatedForTournament, isAuthenticatedForTournamentInsertion } from "../middlewares/auth.js";
const router = express.Router();
router.post("/createMatch",isAuthenticatedForTournamentInsertion, createMatch);
router.get("/all", getAllMatches);
router.get("/match/:matchId", getSingleMatch);
router.get("/match/tournament/:tournamentId", getMatchesByTournament);
router.get("/match/team/:teamId", getMatchesByTeam);
router.get("/match/twoTeams/:team1Id/:team2Id", getMatchesByTwoTeams);
router.get("/match/location/:location", getMatchesByLocation);
router.put("/updateMatch/:matchId",isAuthenticatedForTournament, updateMatch);
router.delete("/deleteMatch/:matchId",isAuthenticatedForTournament, deleteMatch);
export default router;