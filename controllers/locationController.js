import expressAsyncHandler from "express-async-handler";
import db from "../connection/connection.js";

export const addLocation = expressAsyncHandler(async (req, res) => {
    try {
        const {locationname } = req.body;
        const found = await db.query(
        "select * from location where location=$1",
        [locationname]
        );
        if (found.rows.length > 0) {
        res.status(400).json({ message: "Location already exists" });
        } else {
        const result = await db.query(
            "insert into location(location) Values ($1)",
            [locationname]
        );
        res.status(200).json(result.rows);
        }
    } catch (error) {
        console.log(error);
        res.status(500).json({ message: error.message });
    }
    }
);
export const getLocations = expressAsyncHandler(async (req, res) => {
    try {
        const result = await db.query("select * from location");
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});
export const deleteLocation = expressAsyncHandler(async (req, res) => {
    try {
        const { locationid } = req.params;
        const result = await db.query(
        "delete from location where locationid=$1",
        [locationid]
        );
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});
export const updateLocation = expressAsyncHandler(async (req, res) => {
    try {
        const { locationid, locationname } = req.body;
        const result = await db.query(
        "update location set locationname=$1 where locationid=$2",
        [locationname, locationid]
        );
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});
