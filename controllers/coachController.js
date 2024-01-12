import asyncHandler from 'express-async-handler'
import db from "../connection/connection.js"
export const getAllCoaches = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select coach.*,t.teamname from coach left join team as t on coach.coachid=t.coachid order by coach.coachid desc");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const deleteCoach = asyncHandler(async (req, res) => {
    try {
        const { coachId } = req.params;
        const result = await db.query("delete from coach where coachid=$1", [coachId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const modifyCoach = asyncHandler(async (req, res) => {
    try {
        const { coachId } = req.params;
        const { name,picture } = req.body;
        const result = await db.query("update coach set coachname=$1,picture=$2 where coachid=$3", [name,picture, coachId]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const createCoach= asyncHandler(async (req, res) => {
    try {
        const { name,picture } = req.body;
        const result = await db.query("insert into coach(coachname,picture) values($1,$2)", [name,picture]);
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})