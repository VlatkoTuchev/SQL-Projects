-- Creating Table Seniority_Level
create table Seniority_level(
id int identity (1,1) not null,
name nvarchar(50),
constraint PK_Seniority_Level primary key clustered
(
	id asc
)
)
GO

-- Inserting data into Seniority_Level
insert into Seniority_level(name)
values ('Junior'), ('Intermediate'), ('Senor'), ('Lead'), ('Project Manager'), ('Division Manager'), ('Office Manager'),
('Ceo'), ('CTO'), ('CIO')
GO

-- Creating table Location
create table [Location](
id int identity (1,1) not null,
CountryName nvarchar(50),
Continent nvarchar(50),
Region nvarchar(50),
constraint PK_Location primary key clustered
(
	id asc
)
)
GO

-- Inserting values into the table
insert into [Location](CountryName,Continent,Region)
select CountryName as CountryName, Continent as Continent, Region as Region
from WideWorldImporters.Application.Countries
GO

-- Creating table Department
create table Department(
id int identity (1,1) not null,
Name nvarchar(50),
constraint PK_Department primary key clustered
(
	id asc
)
)
GO

-- Inserting Values
insert into Department(Name)
values ('Personal Banking & Operations'), ('Digital Banking Department'), ('Retail Banking & Marketing Department'),
('Wealth Management & Third Party Products'), ('International Banking Division & DFB'), ('Treasury'),
('Information Technology'), ('Corporate Communications'), ('Support Services & Branch Expansion'), ('Human Resources')
GO


-- Creating table Employee
create table Employee(
id int identity (1,1) not null,
FirstName nvarchar(50),
LastName nvarchar(50),
Location int,
Seniority_Level int,
Department int,
constraint PK_Employee primary key clustered
(
	id asc
)
)
GO

--Split FullName into FirstName and LastName and inserting to Employee table
insert into Employee(FirstName,LastName)
select 
SUBSTRING(FullName, 1, CHARINDEX(' ', FullName)-1) as FirstName,
SUBSTRING(FullName, CHARINDEX(' ', FullName)+1, LEN(FullName)-CHARINDEX(' ',FullName)) as LastName
from WideWorldImporters.Application.People
GO

-- Updating Employee table and setting Seniority_Level column to be equally split into 10 categories 
update Employee
set Seniority_Level = case when id % 10 = 0 then 1
							when id % 10 = 1 then 2
							when id % 10 = 2 then 3
							when id % 10 = 3 then 4
							when id % 10 = 4 then 5
							when id % 10 = 5 then 6
							when id % 10 = 6 then 7
							when id % 10 = 7 then 8
							when id % 10 = 8 then 9
							when id % 10 = 9 then 10 end
from Employee
GO

-- Updating Employee table and setting Department column to be equally split into 10 categories 
update Employee
set Department = case when id % 10 = 0 then 10
							when id % 10 = 1 then 9
							when id % 10 = 2 then 8
							when id % 10 = 3 then 7
							when id % 10 = 4 then 6
							when id % 10 = 5 then 5
							when id % 10 = 6 then 4
							when id % 10 = 7 then 3
							when id % 10 = 8 then 2
							when id % 10 = 9 then 1 end
from Employee
GO
 
 -- Creating temp table to hold the ntile split into 190 equal parts and updating Location column with the same values
 create table #temp(id int, split int)

;with cte as
 (
 select id as id, NTILE(190) over (order by id) as split
 from Employee
 )
 insert into #temp(id, split)
 select * from cte
 GO

update e set Location = t.split
from Employee e
inner join #temp t on e.id = t.id
GO


-- Adding Constraints and Foreign keys
ALTER TABLE Employee WITH CHECK ADD CONSTRAINT FK_Employee_Seniority_Level FOREIGN KEY(Seniority_Level)
REFERENCES Seniority_Level (id)
GO

ALTER TABLE Employee CHECK CONSTRAINT FK_Employee_Seniority_Level
GO

ALTER TABLE Employee WITH CHECK ADD CONSTRAINT FK_Employee_Department FOREIGN KEY(Department)
REFERENCES Department (id)
GO

ALTER TABLE Employee CHECK CONSTRAINT FK_Employee_Department
GO

ALTER TABLE Employee WITH CHECK ADD CONSTRAINT FK_Employee_Location FOREIGN KEY(Location)
REFERENCES Location (id)
GO

ALTER TABLE Employee CHECK CONSTRAINT FK_Employee_Location
GO


-- Creating Salary Table
create table Salary(
id int identity (1,1) not null,
EmployeeID int,
[Month] int,
[Year] int,
GrossAmount decimal(18,2),
NetAmount decimal(18,2),
RegularWorkAmount decimal(18,2),
BonusAmount decimal(18,2),
OvertimeAmount decimal(18,2),
VacationDays int,
SickLeaveDays int,
constraint PK_Salary primary key clustered
(
	id asc
)
)
GO

--Inserting data into Salary
	--Inserting Month and Year in temp table #calendar
create table #calendar(month int, year int)
GO

DECLARE @StartDate  date = '20010101';
DECLARE @CutoffDate date = DATEADD(DAY, -1, DATEADD(YEAR, 20, @StartDate));

;WITH seq(n) AS 
(
  SELECT 0 UNION ALL SELECT n + 1 FROM seq
  WHERE n < DATEDIFF(MONTH, @StartDate, @CutoffDate)
),
d(d) AS 
(
  SELECT DATEADD(MONTH, n, @StartDate) FROM seq
)
insert into #calendar(month, year)
SELECT month(d) as month, year(d) as year FROM d
ORDER BY d
OPTION (MAXRECURSION 0);
GO

	-- Creating temp table for EmployeeID only
create table #employee(employeeid int)
	insert into #employee(employeeid)
	select id as employeeID
	from Employee
	GO

	-- Creating temp table for taking every possible combination of every employee and every month and year
	create table #Finally(employeeid int, month int, year int)
	insert into #Finally(employeeid, month, year)
	select employeeid, month, year
	from #calendar
	cross apply #employee
	GO

	-- Inserting the values from #Finally to Salary
	insert into Salary(EmployeeID,Month,Year)
	select * from #Finally
	GO

--Random data between 30000 and 60000 for Gross Amount
update Salary set GrossAmount = floor(RAND(CHECKSUM(newid()))*(60000-30000) + 30000)
GO

-- Setting the Net Amount to be 90% of the gross amount
update Salary set NetAmount = 0.9 * GrossAmount

-- Setting RegularWorkAmount to be 80% of the total net amount
	--creating temp table for holding the total net amout for every employee for every month
create table #Regular(EmpID int, SumNetAmount float)
insert into #Regular(EmpID,SumNetAmount)
select EmployeeID as EmpID,sum(NetAmount) as SumNetAmount
from Salary
group by EmployeeID
GO

update Salary set RegularWorkAmount = SumNetAmount
from Salary s
inner join #Regular r on s.EmployeeID = r.EmpID
Go

--Setting Bonus Amount to be the difference between the NetAmount and RegularWorkAmount for every Odd month
create table #OddMonth(id int, month int, Diff float)
insert into #OddMonth(id,month,Diff)
select id as id, month as month, RegularWorkAmount - NetAmount as Diff
from Salary
where Month % 2 = 1
GO

update s set BonusAmount = om.Diff
from Salary s
inner join #OddMonth om on s.id = om.id
GO

--Setting OvertimeAmount to be the difference between the NetAmount and RegularWorkAmount for every Even month
create table #EvenMonth(id int, month int, Diff float)
insert into #EvenMonth(id,month,Diff)
select id as id, month as month, RegularWorkAmount - NetAmount as Diff
from Salary
where Month % 2 = 0
GO

update s set OvertimeAmount = em.Diff
from Salary s
inner join #EvenMonth em on s.id = em.id
GO

--All employees use 10 vacation days in July and 10 Vacation days in December
update Salary set VacationDays = 10
from Salary
where month = 7 or month = 12
GO

--Additionally random vacation days and sickLeaveDays should be generated with the following
--script:
update salary set vacationDays = vacationDays + vacationdays + (EmployeeID % 2) + (EmployeeID % 3)
where (employeeId + MONTH + year)%5 = 1 or month = 7 or month = 12
GO

update salary set SickLeaveDays = EmployeeId%8, vacationDays = vacationDays +
(EmployeeId % 3)
where (employeeId + MONTH + year)%5 = 2
GO

select * from dbo.salary
where NetAmount <> (regularWorkAmount + BonusAmount + OverTimeAmount)
GO

select * from Salary