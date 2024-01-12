import express from 'express';
import { createCountry, getAllCountries, updateCountry, deleteCountry } from '../controllers/countriesController.js';
import { isAdmin } from '../middlewares/auth.js';
const router = express.Router();
router.post('/createcountry',isAdmin,createCountry);
router.get('/all', getAllCountries);
router.put('/:countryid',isAdmin, updateCountry);
router.delete('/:countryid',isAdmin, deleteCountry);
export default router;