INSERT INTO country(countryID, country) VALUES
(1, 'Australia'),
(2, 'Bangladesh'),
(3, 'England'),
(4, 'India'),
(5, 'New Zealand'),
(6, 'Pakistan'),
(7, 'South Africa'),
(8, 'Sri Lanka'),
(9, 'West Indies'),
(10, 'Zimbabwe'),
(11, 'Afghanistan'),
(12, 'Ireland'),
(13, 'Scotland'),
(14, 'Netherlands'),
(15, 'United Arab Emirates'),
(16, 'Nepal'),
(17, 'Canada'),
(18, 'Kenya'),
(19, 'Namibia'),
(20, 'Papua New Guinea');

alter table match add column matchtype varchar(255) check lower(matchtype) in ('ODI','T20','Test');