import express from 'express';
import { createUmpire, deleteUmpire, getAllUmpires, updateUmpire } from '../controllers/umpireController.js';
import { isAdmin, isAuthenticatedForTournamentInsertion } from '../middlewares/auth.js';
const router = express.Router();
router.post("/createUmpire",isAuthenticatedForTournamentInsertion,createUmpire);
router.get("/all",getAllUmpires)
router.put("/:umpireid",isAdmin,updateUmpire)
router.delete("/:umpireid",isAdmin,deleteUmpire)
export default router;