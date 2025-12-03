CREATE DATABASE softskills_db
GO

USE softskills_db;
GO

---------------------------------------------------------------
-- 2. CREATE TABLES (SQL SERVER VERSION)
---------------------------------------------------------------

-- Rename "User" → Users (избежать конфликтов)
CREATE TABLE Users (
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    email NVARCHAR(150) UNIQUE NOT NULL,
    role NVARCHAR(20) CHECK (role IN ('seeker','offerer','both')),
    created_at DATETIME DEFAULT GETDATE()
);

CREATE TABLE Skill (
    skill_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    category NVARCHAR(100),
    level NVARCHAR(20) CHECK (level IN ('beginner','intermediate','advanced')),
    description NVARCHAR(MAX)
);

CREATE TABLE Request (
    request_id INT IDENTITY(1,1) PRIMARY KEY,
    title NVARCHAR(150) NOT NULL,
    description NVARCHAR(MAX),
    creator_user_id INT,
    created_at DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (creator_user_id) REFERENCES Users(user_id)
);

CREATE TABLE Offer (
    offer_id INT IDENTITY(1,1) PRIMARY KEY,
    request_id INT,
    proposer_user_id INT,
    status NVARCHAR(20) CHECK (status IN ('pending','accepted','rejected')),
    proposed_at DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (request_id) REFERENCES Request(request_id),
    FOREIGN KEY (proposer_user_id) REFERENCES Users(user_id)
);

CREATE TABLE Session (
    session_id INT IDENTITY(1,1) PRIMARY KEY,
    offer_id INT,
    started_at DATETIME,
    duration_minutes INT,
    location_or_link NVARCHAR(200),
    FOREIGN KEY (offer_id) REFERENCES Offer(offer_id)
);

CREATE TABLE Review (
    review_id INT IDENTITY(1,1) PRIMARY KEY,
    session_id INT,
    author_user_id INT,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment NVARCHAR(MAX),
    FOREIGN KEY (session_id) REFERENCES Session(session_id),
    FOREIGN KEY (author_user_id) REFERENCES Users(user_id)
);

-- M:N
CREATE TABLE UserSkill (
    user_id INT,
    skill_id INT,
    PRIMARY KEY (user_id, skill_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (skill_id) REFERENCES Skill(skill_id)
);

CREATE TABLE RequestSkill (
    request_id INT,
    skill_id INT,
    PRIMARY KEY (request_id, skill_id),
    FOREIGN KEY (request_id) REFERENCES Request(request_id),
    FOREIGN KEY (skill_id) REFERENCES Skill(skill_id)
);

---------------------------------------------------------------
-- 3. INSERT TEST DATA
---------------------------------------------------------------

INSERT INTO Users (name, email, role) VALUES
('Alice', 'alice@mail.com', 'seeker'),
('Bob', 'bob@mail.com', 'offerer'),
('Charlie', 'charlie@mail.com', 'both');

INSERT INTO Skill (name, category, level, description) VALUES
('Public Speaking', 'Communication', 'advanced', 'Expert public speaking'),
('Time Management', 'Productivity', 'intermediate', 'Manage time effectively'),
('Team Leadership', 'Management', 'advanced', 'Lead teams productively');

INSERT INTO UserSkill VALUES
(1, 1),
(2, 2),
(3, 1),
(3, 3);

INSERT INTO Request (title, description, creator_user_id) VALUES
('Need help with public speaking', 'Preparing for a conference', 1),
('Want to improve time management', 'Busy schedule', 1);

INSERT INTO RequestSkill VALUES
(1, 1),
(2, 2);

INSERT INTO Offer (request_id, proposer_user_id, status) VALUES
(1, 2, 'accepted'),
(2, 3, 'pending');

INSERT INTO Session (offer_id, started_at, duration_minutes, location_or_link)
VALUES
(1, GETDATE(), 60, 'Zoom');

INSERT INTO Review (session_id, author_user_id, rating, comment) VALUES
(1, 1, 5, 'Great session, very helpful!');


---------------------------------------------------------------
-- 4. FUNCTION (T-SQL)
--    Avg rating for user (as proposer)
---------------------------------------------------------------
GO
CREATE FUNCTION GetUserAverageRating(@user_id INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @avg DECIMAL(5,2);

    SELECT @avg = AVG(r.rating * 1.0)
    FROM Review r
    JOIN Session s ON r.session_id = s.session_id
    JOIN Offer o ON s.offer_id = o.offer_id
    WHERE o.proposer_user_id = @user_id;

    RETURN @avg;
END;
GO

---------------------------------------------------------------
-- 5. STORED PROCEDURE
--    Returns all offers on a request
---------------------------------------------------------------
GO
CREATE PROCEDURE GetOffersForRequest
    @req_id INT
AS
BEGIN
    SELECT o.offer_id, o.status, u.name AS proposer
    FROM Offer o
    JOIN Users u ON o.proposer_user_id = u.user_id
    WHERE o.request_id = @req_id;
END;
GO

---------------------------------------------------------------
-- 6. TRIGGER
--    Auto-reject other offers when one becomes accepted
---------------------------------------------------------------
GO
CREATE TRIGGER trg_RejectOtherOffers
ON Offer
AFTER UPDATE
AS
BEGIN
    IF UPDATE(status)
    BEGIN
        UPDATE Offer
        SET status = 'rejected'
        WHERE request_id = (SELECT request_id FROM inserted)
          AND offer_id <> (SELECT offer_id FROM inserted)
          AND (SELECT status FROM inserted) = 'accepted';
    END
END;
GO
-- Для отладки: покажем основные строки (выполняй по необходимости)
-- SELECT * FROM users;
-- SELECT * FROM skills;
-- SELECT * FROM requests;
-- SELECT * FROM request_skills;
-- SELECT * FROM user_skills;
-- SELECT * FROM offers;
-- SELECT * FROM sessions;
-- SELECT * FROM reviews;