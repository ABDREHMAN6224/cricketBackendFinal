import asyncHandler from 'express-async-handler';
import db from '../connection/connection.js';
export const createUmpire = asyncHandler(async (req, res) => {
    try {
        const { umpirename, noofmatches, countryid,umpirepicpath } = req.body;
        console.log(req.body);
        const result = await db.query('INSERT INTO umpire(umpirename,nomatches,countryid,umpirepicpath) VALUES ($1,$2,$3,$4)', [umpirename, noofmatches, countryid,umpirepicpath]);
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getAllUmpires = asyncHandler(async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM umpire join country using(countryid) order by umpireid desc');
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const updateUmpire = asyncHandler(async (req, res) => {
    try {
        const { umpireid } = req.params;
        const { umpirename, countryid,picpath } = req.body;
        const result = await db.query('UPDATE umpire SET umpirename=$1,countryid=$2,umpirepicpath=$3 WHERE umpireid=$4', [umpirename,countryid,picpath, umpireid]);
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const deleteUmpire = asyncHandler(async (req, res) => {
    try {
        const { umpireid } = req.params;
        const result = await db.query('DELETE FROM umpire WHERE umpireid=$1', [umpireid]);
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
}
)