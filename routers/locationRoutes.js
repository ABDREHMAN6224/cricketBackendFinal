import express from 'express';
import { addLocation, getLocations, deleteLocation, updateLocation } from '../controllers/locationController.js';
import { isAdmin } from '../middlewares/auth.js';
const router = express.Router();
router.route('/').get(getLocations).post(isAdmin,addLocation);
router.route('/:locationid').delete(isAdmin,deleteLocation).put(isAdmin,updateLocation);
export default router;