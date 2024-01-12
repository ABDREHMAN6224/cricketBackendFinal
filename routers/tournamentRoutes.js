import express from 'express';
import { createTournament, deleteTournament, getAllTournaments, getTournamentById, getTournamentMatches, updateTournament } from '../controllers/tournamentControler.js';
import { isAuthenticatedForTournament, isAuthenticatedForTournamentInsertion } from '../middlewares/auth.js';
const router = express.Router();

router.get("/all", getAllTournaments)
router.put("/:tournamentID",isAuthenticatedForTournament, updateTournament)
router.delete("/:tournamentID",isAuthenticatedForTournament, deleteTournament)
router.post("/create",isAuthenticatedForTournamentInsertion, createTournament)
router.get("/:tournamentID", getTournamentById)
router.get("/matches/:tournamentID", getTournamentMatches)
export default router;