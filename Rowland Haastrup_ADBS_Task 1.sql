--- PART 1
Create Database LibraryDB

USE LibraryDB;
GO


--- Creating the Tables
CREATE TABLE Members(
	MemberID INT IDENTITY(1,1) PRIMARY KEY,
	FirstName NVARCHAR(50) NOT NULL,
	LastName NVARCHAR(50) NOT NULL,
	Address1 NVARCHAR(100) NOT NULL,
	Address2 NVARCHAR(100) NOT NULL,
	PostCode NVARCHAR(20) NOT NULL,
	DOB DATE NOT NULL,
	Email NVARCHAR(100) UNIQUE CHECK (Email LIKE '%_@_%._%'),
	Telephone NVARCHAR(20),
	Username NVARCHAR(20) NOT NULL,
	Password NVARCHAR(20) NOT NULL,
	DateJoined DATE NOT NULL,
	DateLeft DATE);
	
--- Creating the Items Table
CREATE TABLE Item(
	ItemID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	ItemTitle NVARCHAR(200) NOT NULL,
	ItemTypeID INT NOT NULL,
	Author NVARCHAR(100) NOT NULL,
	YearOfPublication INT NOT NULL,
	DateAdded DATE NOT NULL,
	ISBN NVARCHAR(20),
	ItemStatusID INT NOT NULL,
	DateRemoved DATE,);
	
CREATE TABLE ItemStatus(
	ItemStatusID INT NOT NULL PRIMARY KEY,
	ItemStatus NVARCHAR(20) NOT NULL);
	
ALTER TABLE Item
	ADD CONSTRAINT FK_Item_ItemStatus
	FOREIGN KEY (ItemStatusID) REFERENCES ItemStatus(ItemStatusID)
ALTER TABLE Item
	WITH CHECK
	CHECK CONSTRAINT FK_Item_ItemStatus;

INSERT INTO ItemStatus(ItemStatusID, ItemStatus)
VALUES
(1, 'Available'),
(2, 'On Loan'),
(3, 'Overdue'),
(4, 'Lost/Removed');

CREATE TABLE ItemType(
	ItemTypeID INT NOT NULL PRIMARY KEY,
	ItemType NVARCHAR(50) NOT NULL);

ALTER TABLE Item
	ADD CONSTRAINT FK_Item_ItemType
	FOREIGN KEY (ItemTypeID) REFERENCES ItemType(ItemTypeID)
ALTER TABLE Item
	WITH CHECK
	CHECK CONSTRAINT FK_Item_ItemType;

INSERT INTO ItemType (ItemTypeID, ItemType)
VALUES
(1, 'Book'),
(2, 'Journal'),
(3, 'DVD'),
(4, 'Other Media');

--- Create Loans Table
CREATE TABLE Loans(
	LoanID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	MemberID INT NOT NULL,
	ItemID INT NOT NULL,
	DateTakenOut DATE NOT NULL,
	DueDate DATE NOT NULL,
	DateReturned DATE,
	OverdueFee DECIMAL(5, 2) DEFAULT 0);
	
--- Constraint on MemberID & ItemID column to the Loans table
ALTER TABLE Loans
	ADD CONSTRAINT FK_Loan_Members
	FOREIGN KEY (MemberID) REFERENCES Members(MemberID)

ALTER TABLE Loans
	ADD CONSTRAINT FK_Loan_Items
	FOREIGN KEY (ItemID) REFERENCES Item(ItemID)


--- Creating the OverdueFines table
CREATE TABLE OverdueFines(
	OverdueFineID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    LoanID INT NOT NULL,
	MemberID INT NOT NULL,
    OverdueFine DECIMAL(10,2) NOT NULL,
    AmountRepaid DECIMAL(10,2) NOT NULL,
    OutstandingBalance DECIMAL(10,2) NOT NULL);

 --- Adding Constraint to the LoanID column in the OverdueFines table to ensure referential integrity
ALTER TABLE OverdueFines
	ADD CONSTRAINT FK_Loan_Fines
	FOREIGN KEY (LoanID) REFERENCES Loans(LoanID)
	
ALTER TABLE OverdueFines
	ADD CONSTRAINT FK_Member_Fines
	FOREIGN KEY (MemberID) REFERENCES Members(MemberID)

--- Creating the Repayment table
CREATE TABLE Repayments(
	RepaymentID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	MemberID INT NOT NULL,
	OverdueFineID INT NOT NULL,
	AmountRepaid DECIMAL(10,2) NOT NULL,
	RepaymentDate DATE NOT NULL,
	RepaymentMethodID  INT NOT NULL);

CREATE TABLE RepaymentMethod(
	RepaymentMethodID  INT NOT NULL PRIMARY KEY,
	RepaymentMethod NVARCHAR(20) NOT NULL);

ALTER TABLE Repayments
	ADD CONSTRAINT FK_Repayments_RepaymentMethodID
	FOREIGN KEY (RepaymentMethodID) REFERENCES RepaymentMethod(RepaymentMethodID);
ALTER TABLE Repayments
	WITH CHECK
	CHECK CONSTRAINT FK_Repayments_RepaymentMethodID;

INSERT INTO RepaymentMethod(RepaymentMethodID, RepaymentMethod)
VALUES
(1, 'Cash'),
(2, 'Card');

--- Constraints to the OverdueFineID and MemberID
ALTER TABLE Repayments
	ADD CONSTRAINT FK_Repayment_Fines
	FOREIGN KEY (OverdueFineID) REFERENCES OverdueFines(OverdueFineID)

ALTER TABLE Repayments
	ADD CONSTRAINT FK_Repayment_Members
	FOREIGN KEY (MemberID) REFERENCES Members(MemberID)


--- Creating the Archived Members Table
CREATE TABLE ArchivedMembers(
	MemberID INT NOT NULL PRIMARY KEY,
	FirstName NVARCHAR(50) NOT NULL,
	LastName NVARCHAR(50) NOT NULL,
	Address1 NVARCHAR(100) NOT NULL,
	Address2 NVARCHAR(100) NOT NULL,
	PostCode NVARCHAR(20) NOT NULL,
	DOB DATE NOT NULL,
	Email NVARCHAR(100) UNIQUE CHECK (Email LIKE '%_@_%._%'),
	Telephone NVARCHAR(20),
	Username NVARCHAR(20) NOT NULL,
	Password NVARCHAR(20) NOT NULL,
	DateJoined DATE NOT NULL,
	DateLeft DATE);

--- Creating the Trigger that archives the deleted customers
CREATE TRIGGER tr_Archive_DeletedMembers ON Members
AFTER DELETE
AS BEGIN
    DECLARE @currentDateTime DATETIME
    SET @currentDateTime = GETDATE()

    INSERT INTO ArchivedMembers
    (MemberID, FirstName, LastName, Address1, Address2, PostCode, DOB, Email, Telephone, Username, Password, DateJoined, DateLeft)
    SELECT
    d.MemberID, d.FirstName, d.LastName, d.Address1, d.Address2, d.PostCode, d.DOB, d.Email, d.Telephone, d.Username,
    d.Password, d.DateJoined, @currentDateTime
    FROM deleted d
END;

---- I would create a trigger to calculate and update the overdue fee whenever a loan is returned as shown below
--- Each time AmountRepaid is updated in the Overdue table, there is a need for the OverdueFee in the table to be updated

CREATE TRIGGER tr_updateoverduefines_fromloans ON Loans
AFTER UPDATE
AS BEGIN
  UPDATE Loans SET OverdueFee = DATEDIFF(DAY, DueDate, DateReturned) * 0.1
  WHERE DateReturned IS NOT NULL AND DueDate < DateReturned

  INSERT INTO overduefines(LoanID, MemberID, OverdueFine, AmountRepaid, OutstandingBalance)
  SELECT i.LoanID, i.MemberID, l.OverdueFee, 0, l.OverdueFee
  FROM inserted i
  INNER JOIN Loans l ON i.LoanID = l.LoanID
  WHERE i.DateReturned IS NOT NULL AND i.DueDate < i.DateReturned
END;


--- I will be writing query for the necessary Stored Procedures for the Library Database
---STORED PROCEDURES 1
--- Insert Item stored procedure
CREATE PROCEDURE InsertItem
    @ItemTitle nvarchar(200),
    @ItemTypeID INT,
    @Author nvarchar(100),
    @YearOfPublication int,
    @DateAdded date,
	@ISBN nvarchar(20) = NULL,
    @ItemStatusID INT,
	@DateRemoved date = NULL
AS
BEGIN
    -- Check if item already exists in database
    IF EXISTS (SELECT * FROM Item WHERE ItemTitle = @ItemTitle AND Author = @Author)
    BEGIN
        RAISERROR ('Item already exists in the database', 16, 1);
        RETURN;
    END
    -- Insert new item into database
    INSERT INTO Item (ItemTitle, ItemTypeID, Author, YearOfPublication, DateAdded, ISBN, ItemStatusID, DateRemoved)
    VALUES (@ItemTitle, @ItemTypeID, @Author, @YearOfPublication, @DateAdded, @ISBN, @ItemStatusID, @DateRemoved);
END

---Inserting the Items into the Item table
EXEC InsertItem --- 1st Item
	@ItemTitle = 'The Battle of Mogadishu', @ItemTypeID = '1', @Author = 'Jones Ibans', @YearOfPublication = '1998', @DateAdded = '2004-10-10',
	@ISBN = '978-1-72880-808-4', @ItemStatusID = '1';

EXEC InsertItem --- 2nd Item
	@ItemTitle = 'Things Fall Apart', @ItemTypeID = '1', @Author = 'Chinua Achebe', @YearOfPublication = '1991', @DateAdded = '2000-04-19',
	@ISBN = '129-1-52781-212-7', @ItemStatusID = '1';

EXEC InsertItem --- 3rd Item
	@ItemTitle = 'Anaconda', @ItemTypeID = '3', @Author = 'Paul Smith', @YearOfPublication = '1999', @DateAdded = '2005-11-11',
	@ItemStatusID = '4', @DateRemoved = '2022-01-23';

EXEC InsertItem --- 4th Item
	@ItemTitle = 'British Health Journal', @ItemTypeID = '2', @Author = 'Ben Kobe', @YearOfPublication = '2011', @DateAdded = '2017-06-03',
	@ItemStatusID = '3';

EXEC InsertItem --- 5th Item
	@ItemTitle = 'The Life of Joe Blind', @ItemTypeID = '4', @Author = 'Mike Simps', @YearOfPublication = '2002', @DateAdded = '2007-10-02',
	@ItemStatusID = '1'

EXEC InsertItem --- 6th Item
	@ItemTitle = 'Assault in Mogadishu', @ItemTypeID = '4', @Author = 'Don Dada', @YearOfPublication = '1996', @DateAdded = '2001-10-02',
	@ItemStatusID = '1'

EXEC InsertItem --- 7th Item
	@ItemTitle = 'Trials of Jimmy Johnson', @ItemTypeID = '1', @Author = 'Kiki Mapami', @YearOfPublication = '1999', @DateAdded = '2002-04-19',
	@ISBN = '110-6-52081-292-1', @ItemStatusID = '1';

EXEC InsertItem --- 8th Item
	@ItemTitle = 'Things Fall Apart, Volume 2', @ItemTypeID = '1', @Author = 'Chinua Achebe', @YearOfPublication = '1997', @DateAdded = '2010-05-19',
	@ISBN = '121-1-52981-232-6', @ItemStatusID = '1';

SELECT * from Item ---checking


--- PART 2a. STORED PROCEDURE TO SEARCH THE CATALOG FOR MATCHING CHARACTER STRINGS BY TITLE
CREATE PROCEDURE SearchCatalog
    @TitleSearchString NVARCHAR(100)
AS
BEGIN
    SELECT * FROM Item
    WHERE ItemTitle LIKE '%' + @TitleSearchString + '%'
    ORDER BY YearOfPublication DESC
END

EXEC SearchCatalog 'of'

--- PART 2c. STORED PROCEDURE TO INSERT A NEW MEMBER INTO THE DATABASE (Check for Part 2b after Part 2d)
CREATE PROCEDURE InsertMember
	@Firstname nvarchar (50),
    @LastName nvarchar(50),
    @Address1 nvarchar(100),
	@Address2 nvarchar(100),
	@PostCode nvarchar(20),
    @DOB date,
	@Email nvarchar(100) = NULL,
    @Telephone nvarchar(20) = NULL,
    @Username nvarchar(20),
    @Password nvarchar(20),
	@DateJoined date,
	@DateLeft date = NULL
AS
BEGIN
    INSERT INTO Members (FirstName, LastName, Address1, Address2, PostCode, DOB, Email, Telephone, Username, Password, DateJoined, DateLeft)
    VALUES (@FirstName, @LastName, @Address1, @Address2, @PostCode, @DOB, @Email, @Telephone, @Username, @Password, @DateJoined, @DateLeft)
END

---Inserting Records into the Members table created to test the stored procedure
EXEC InsertMember  --- 1st Member
	@FirstName = 'John', @LastName = 'Smith', @Address1 = '12 Paulson street', @Address2 = 'Manchester', @PostCode = 'M10 A21', @DOB = '2001-01-21',
	@Email = 'j.smith@yahoo.com', @Telephone = '077-2234-1234', @Username = 'JSmith', @Password = 'JSmith01.', @DateJoined = '2022-02-03';

EXEC InsertMember  --- 2nd Member
	@FirstName = 'Susan', @LastName = 'Ojo', @Address1 = '33 Moston Lane', @Address2 = 'Manchester', @PostCode = 'M14 4RT', @DOB = '1998-09-14',
	@Email = 'susanojo@hotmail.com', @Telephone = '072-2664-0987', @Username = 'SOjo', @Password = 'SusanOjo01.', @DateJoined = '2022-08-23';

EXEC InsertMember  --- 3rd Member
	@FirstName = 'Don', @LastName = 'Baba', @Address1 = '6 Polefield street', @Address2 = 'Manchester', @PostCode = 'M9 A11', @DOB = '1996-02-11',
	@Email = 'don_babs@yahoo.co.uk', @Telephone = '074-6634-1935', @Username = 'DonBaba_', @Password = 'DonBabs99_', @DateJoined = '2021-12-29';

EXEC InsertMember  --- 4th Member
	@FirstName = 'Ade', @LastName = 'Olajuwon', @Address1 = '155 Rochdale Road', @Address2 = 'Manchester', @PostCode = 'M9 G24', @DOB = '2000-11-08',
	@Email = 'Adejuwon01@gmail.com', @Telephone = '076-1234-5678', @Username = 'AlaskaBaba', @Password = 'Adepumping007', @DateJoined = '2022-05-12';

EXEC InsertMember  --- 5th Member
	@FirstName = 'Josephine', @LastName = 'Stone', @Address1 = 'Flat B, 22 Edinburgh street', @Address2 = 'Oldham', @PostCode = 'OL8 B91', @DOB = '1992-02-21',
	@Email = 'josephinestone@gmail.com', @Telephone = '072-9876-5432', @Username = 'JayBaby', @Password = 'joseSto101!', @DateJoined = '2023-01-19';

EXEC InsertMember  --- 6th Member
	@FirstName = 'Joy', @LastName = 'Kukuru', @Address1 = 'Flat E, 22 Edinburgh street', @Address2 = 'Oldham', @PostCode = 'OL8 B91', @DOB = '1995-02-21',
	@Email = 'joykukuru@gmail.com', @Telephone = '072-9876-5432', @Username = 'JayBaby', @Password = 'joseSto101!', @DateJoined = '2023-01-19';

SELECT * from Members ---checking if the stored procedure worked

---STORED PROCEDURES 2
--- Insert Loans
CREATE PROCEDURE InsertLoan
    @MemberId int,
    @ItemId int,
    @DateTakenOut date,
	@DueDate date,
	@DateReturned date = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- Check if item is available for loan
    IF NOT EXISTS (SELECT * FROM Item WHERE ItemID = @ItemID AND ItemStatusID = '1') ---NB: 1 = Available
    BEGIN
        RAISERROR ('Item is not available for loan', 16, 1);
        RETURN;
    END
    -- Insert new loan into database
    INSERT INTO Loans (MemberID, ItemID, DateTakenOut, DueDate, DateReturned)
    VALUES (@MemberID, @ItemID, @DateTakenOut, @DueDate, @DateReturned);
    -- Update item status to On Loan
    UPDATE Item SET ItemStatusID = '2' WHERE ItemId = @ItemId; --- NB: 2 = On Loan
END

---Inserting Loans into the Loans table
EXEC InsertLoan --- 1st Loan
	@MemberId = '1', @ItemId = '2', @DateTakenOut = '2023-01-31', @DueDate = '2023-02-14'

EXEC InsertLoan --- 2nd Loan
	@MemberID = '3', @ItemID = '6', @DateTakenOut = '2022-12-29', @DueDate = '2023-01-31'

EXEC InsertLoan
	@MemberID = '4', @ItemID = '8', @Datetakenout = '2023-02-19', @DueDate = '2023-02-24'

SELECT * from Loans ---checking

--- PART 2d. STORED PROCEDURE TO UPDATE THE DETAILS FOR AN EXISTING MEMBER
CREATE PROCEDURE sp_UpdateMember
    @MemberID int,
    @Firstname nvarchar (50) = NULL,
    @LastName nvarchar(50) = NULL,
    @Address1 nvarchar(100) = NULL,
	@Address2 nvarchar(100) = NULL,
	@PostCode nvarchar(20) = NULL,
    @DOB date = NULL,
	@Email nvarchar(100) = NULL,
    @Telephone nvarchar(20) = NULL,
    @Username nvarchar(20) = NULL,
    @Password nvarchar(20) = NULL,
	@DateJoined date = NULL,
	@DateLeft date = NULL
AS
BEGIN
    UPDATE Members
    SET Firstname = COALESCE(@Firstname, FirstName), LastName = COALESCE(@LastName, LastName), Address1 = COALESCE(@Address1, Address1),
	Address2 = COALESCE(@Address2, Address2), PostCode = COALESCE(@PostCode, PostCode), DOB = COALESCE(@DOB, DOB),
	Email = COALESCE(@Email, Email), Telephone = COALESCE(@Telephone, Telephone), Username = COALESCE(@Username, Username),
	Password = COALESCE(@Password, Password), DateJoined = COALESCE(@DateJoined, DateJoined), DateLeft = COALESCE(@DateLeft, DateLeft)
    WHERE MemberID = @MemberID
END

EXEC sp_UpdateMember @MemberID = 2, @LastName = 'Roberts', @Address1 = '21, Charlestown Road', @PostCode = 'M9 7EB' --Updating a member to test
 

--- PART 2b. STORED PROCEDURE TO RETURN A FULL LIST OF ALL ITEMS CURRENTLY ON LOAN WITH DUE DATE LESS THAN 5 DAYS FROM CURRENT DATE
CREATE PROCEDURE sp_GetItemsOnLoan_DueLessThan5Days
  @CurrentDate DATETIME
AS
BEGIN
  SET NOCOUNT ON;
  SELECT l.LoanID, CONCAT(m.FirstName,' ',m.LastName) as MemberName, i.ItemTitle, l.DueDate
  FROM 
    Loans l
    INNER JOIN Members m ON l.MemberID = m.MemberID
    INNER JOIN Item i ON l.ItemID = i.ItemID
  WHERE 
    l.DueDate <= DATEADD(day, 5, @CurrentDate) -- due date is less than 5 days from current date
    AND l.DateReturned IS NULL -- item is still on loan
END

EXEC sp_GetItemsOnLoan_DueLessThan5Days @CurrentDate = '2023-02-28'


---PART 3. VIEW CONTAINING THE LOAN HISTORY, PREVIOUS & CURRENT LOANS, DETAILS OF ITEMS BORROWED, BORROWED DATE, DUE DATE & ASSOCIATED FINES FOR EACH LOAN
CREATE VIEW LoanHistoryDetails AS
SELECT CONCAT(m.FirstName,' ',m.LastName) as FullName, l.LoanID, l.DateTakenOut, l.DueDate, l.DateReturned, o.OverdueFine,
				i.ItemTitle, it.ItemType, i.Author, i.YearOfPublication, i.DateAdded, i.ISBN, its.ItemStatus
FROM 
    Loans l INNER JOIN OverdueFines o ON l.LoanID = o.LoanID
	INNER JOIN  Members m ON o.MemberID = m.MemberID
    INNER JOIN Item i ON l.ItemID = i.ItemID
	INNER JOIN ItemType it ON it.ItemTypeID = i.ItemTypeID
	INNER JOIN ItemStatus its ON its.ItemStatusID = i.ItemStatusID;
GO

SELECT * FROM LoanHistoryDetails ---testing the created view (Nothing will show yet since no item on loan has been returned yet)
--- we will try the below again after Part 4 where some items have been returned

select * from OverdueFines
--- PART 4. Creating a trigger so that the current status of an item automatically updates to Available when the book is returned. 
CREATE TRIGGER tr_UpdateItemStatus
ON Loans
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Item
    SET ItemStatusID = '1'  ---N/B: 1 = Available as per ItemStatus Table
    FROM Item
    INNER JOIN inserted ins ON Item.ItemID = ins.ItemID
    WHERE ins.DateReturned IS NOT NULL AND ins.DateReturned <> '';

    UPDATE OverdueFines
    SET OutstandingBalance = OverdueFine - AmountRepaid
    FROM OverdueFines
    INNER JOIN inserted ins ON OverdueFines.LoanID = ins.LoanID
    WHERE ins.DateReturned IS NOT NULL AND ins.DateReturned <> '';

END;

--- Now I will return some items to create populate the OverdueFee column of the Loans table as well as return CurrentStatus to available & give an OverdueFine on OverdueFines table
UPDATE Loans
SET DateReturned = '2023-02-17'
WHERE LoanID = 1;

UPDATE Loans
SET DateReturned = '2023-02-02'
WHERE LoanID = 2;

Select * from Loans ---to check if the loan table was updated
SELECT * FROM LoanHistoryDetails --- now we are testing this again from Part 3
Select * from Item ---to check if Item table has been updated
Select * from OverdueFines ---to check if OverdueFines table has been updated


--- PART 5. Provide a function, view, or SELECT query which allows the library to identify the total number of loans made on a specified date.
--- The Select Query
SELECT COUNT(*) AS num_loans
FROM loans
WHERE DateTakenOut = '2023-02-19'

--- The View
CREATE VIEW loans_by_date AS 
SELECT DateTakenOut AS loan_date, COUNT(*) AS total_loans 
FROM Loans 
GROUP BY DateTakenOut;

SELECT * FROM loans_by_date WHERE loan_date = '2023-02-19'  --to test the view


--- PART 6. 
--- i. Insert Repayment
CREATE PROCEDURE InsertRepayment
	@MemberID int,
	@OverdueFineID int,
	@AmountRepaid decimal(10,2),
	@RepaymentDate date,
	@RepaymentMethodID INT
AS
BEGIN
	INSERT INTO Repayments (MemberID, OverdueFineID, AmountRepaid, RepaymentDate, RepaymentMethodID)
	VALUES (@MemberID, @OverdueFineID, @AmountRepaid, @RepaymentDate, @RepaymentMethodID);
	UPDATE OverdueFines SET AmountRepaid = @AmountRepaid, OutstandingBalance = OverdueFine - @AmountRepaid
	WHERE OverdueFineID = @OverdueFineID;
END

--- To Test by Inserting Repayments for the 2 loans with Overdue Fines
EXECUTE InsertRepayment @memberID = 1, @OverdueFineID = 1, @AmountRepaid = 0.20, @RepaymentDate = '2022-03-06', @RepaymentMethodID = '2';
EXECUTE InsertRepayment @memberID = 3, @OverdueFineID = 2, @AmountRepaid = 0.20, @RepaymentDate = '2022-03-01', @RepaymentMethodID = '1';

select * from Repayments  ---to check if procedure worked 
select * from OverdueFines ---to check if overduefines table has been duly updated


---PART 7.
--i. Testing the tr_Archive_DeletedMembers trigger by deleting a member from the Members table
DELETE FROM Members WHERE MemberID = 6 ---testing 
select * from ArchivedMembers where MemberID = 6 ---checking the ArchivedMembers tables to see if it worked

--ii. Get Loan History stored procedure
CREATE PROCEDURE GetLoanHistory
    @MemberID INT
AS
BEGIN
    SELECT Loans.LoanID, Item.ItemTitle, ItemType.ItemType, Loans.DateTakenOut, Loans.DueDate, Loans.DateReturned
    FROM Loans
    INNER JOIN Item ON Loans.ItemID = Item.ItemID
	INNER JOIN ItemType ON Item.ItemTypeID = ItemType.ItemTypeID
    WHERE Loans.MemberID = @MemberID
    ORDER BY Loans.DateTakenOut DESC
END

EXEC GetLoanHistory 3 --testing/checking

---iii. Get Overdue Loans stored procedure
CREATE PROCEDURE GetOverdueLoans
AS
BEGIN
    SELECT Loans.LoanID, CONCAT(Members.FirstName,' ',Members.LastName) as FullName, Item.ItemTitle, ItemType.ItemType,
	Loans.DateTakenOut, Loans.DueDate, DATEDIFF(DAY, Loans.DueDate, GETDATE()) * 0.1 AS OverdueFee
    FROM Loans
    INNER JOIN Members ON Loans.MemberID = Members.MemberID
    INNER JOIN Item ON Loans.ItemID = Item.ItemID
	INNER JOIN ItemType ON Item.ItemTypeID = ItemType.ItemTypeID
    WHERE Loans.DateReturned IS NULL AND GETDATE() > Loans.DueDate
    ORDER BY Loans.DateTakenOut DESC
END

EXEC GetOverdueLoans --testing/checking

-- iv. User-defined function GetNumberOfLoansForMember
CREATE FUNCTION GetNumberOfLoansForMember (@memberID INT)
RETURNS INT
AS
BEGIN
    DECLARE @numLoans INT
    SELECT @numLoans = COUNT(*) FROM Loans WHERE MemberID = @memberID AND DateReturned IS NULL
    RETURN @numLoans
END

SELECT dbo.GetNumberOfLoansForMember (1) as 'Number of Loans' --testing/checking

--v. User-defined function GetAvailableItemsByType
CREATE FUNCTION GetAvailableItemsByType (@ItemTypeID INT)
RETURNS INT
AS
BEGIN
    DECLARE @numAvailable INT
    SELECT @numAvailable = COUNT(*) FROM Item
	WHERE ItemTypeID = @ItemTypeID AND ItemStatusID = '1'   --- N/B: 1 = Available (as per ItemStatus table)
    RETURN @numAvailable
END

SELECT dbo.GetAvailableItemsByType ('1') as 'Number of Books Available' --testing/checking