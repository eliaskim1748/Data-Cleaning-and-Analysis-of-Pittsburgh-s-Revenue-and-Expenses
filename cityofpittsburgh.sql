-- Cleaning data in MySQL 

select *
from portfolioproject.cityofpittsburgh;
    
show fields
from portfolioproject.cityofpittsburgh;

-- Creating a temporary table

create table pittsburgh_dataset as
select *
from portfolioproject.cityofpittsburgh;

-- Converting type

alter table pittsburgh_dataset
modify column general_ledger_date date;

alter table pittsburgh_dataset
modify column amount decimal(65,2);

-- Parsing and splitting data

alter table pittsburgh_dataset
add column date_day int,
add column date_month int,
add column date_year int;

update pittsburgh_dataset
set date_day = day(general_ledger_date),
    date_month = month(general_ledger_date),
    date_year = year(general_ledger_date);

-- Standardizing formats 

alter table pittsburgh_dataset
rename column _id to id,
rename column ledger_descrpition to ledger_description;

update pittsburgh_dataset
set fund_description = upper(fund_description),
    department_name = upper(department_name),
    object_account_description = upper(object_account_description),
    ledger_description = upper(ledger_description);

update pittsburgh_dataset
set department_name = 
	replace(
		replace(
			replace(department_name
            		, ' ', '<>')
		, '><', '')
	, '<>', ' '),
    object_account_description = 
	replace(
		replace(
			replace(object_account_description
            		, ' ', '<>')
		, '><', '')
	, '<>', ' ');

update pittsburgh_dataset
set fund_description = 
	replace(
		replace(
			replace(fund_description
            		, ' - ', '-')
		, ' -', '-')
	, '- ', '-'),
    department_name = 
	replace(
		replace(
			replace(department_name
            		, ' - ', '-')
		, ' -', '-')
	, '- ', '-'),
    object_account_description = 
	replace(
		replace(
			replace(object_account_description
            		, ' - ', '-')
		, ' -', '-')
	, '- ', '-');
    
update pittsburgh_dataset
set object_account_description = 
	replace(
		replace(
			replace(object_account_description
            		, ' / ', '/')
		, ' /', '/')
	, '/ ', '/');

update pittsburgh_dataset
set fund_description = replace(fund_description, '.', ''),
    object_account_description = replace(object_account_description, '.', '');

update pittsburgh_dataset
set fund_description = replace(fund_description, 'TRUST FUND', 'TF');

-- Correcting inaccuracies 

-- I noticed that there was a character limit of 30, so some entries were cut off
-- For the sake of time, I only corrected other inaccuracies

update pittsburgh_dataset
set fund_description = 
	case when fund_description = 'TREE TAXING BODIES' then 'THREE TAXING BODIES'
	    when fund_description = 'DURG ABUSE RESISTANCE ED TF' then 'DRUG ABUSE RESISTANCE ED TF'
            else fund_description
	end;

update pittsburgh_dataset
set object_account_description = 
	case when object_account_description = '2% LOCAL SARE OF SLOTS REVENUE' then '2% LOCAL SHARE OF SLOTS REVENUE'
	    when object_account_description = 'INTERGOVEN REVENUE-FEDERAL' then 'INTERGOVERN REVENUE-FEDERAL'
            when object_account_description = 'INTERGOVEN REVENUE-STATE' then 'INTERGOVERN REVENUE-STATE'
            else object_account_description
	end;
  
update pittsburgh_dataset
set amount = 
	case when ledger_description = 'EXPENSES' then -ABS(amount)
	    when ledger_description = 'REVENUES' then ABS(amount)
	end;

-- I noticed that rows with the ledger description TRANSFERS had null amounts
-- Since internal transfers are neither a revenue or expense, I replaced the nulls with 0

update pittsburgh_dataset
set amount = 0 
where amount is null;

-- Removing duplicates

with rownumcte as (
    select *, 
	row_number() over(
	    partition by 
		fund_number,
		department_number,
		object_account_number,
		general_ledger_date,
		amount
	    order by id
	) as rownum
    from
	pittsburgh_dataset
)
select *
from rownumcte
where rownum > 1;
	
-- Although it appears as though there are duplicates, there most likely are not
-- The City of Pittsburgh is audited on a regular basis so any duplicates would be flagged as deficiencies

-- Dropping unused columns

alter table pittsburgh_dataset
drop column cost_center_number,
drop column cost_center_description;

-- Exploring data in MySQL

-- Q1. How many reports were made in each category?

select ledger_description,
    count(*) as report_count
from pittsburgh_dataset
group by ledger_description;

-- Q2. What was the distribution of reports by department?

select department_name,
    count(department_name) as reports
from pittsburgh_dataset
group by department_name
order by reports;

-- Q3. Which department had the highest total profit? Lowest?

select department_name,
    sum(amount) as total_profit
from pittsburgh_dataset
group by department_name
order by total_profit desc;

-- Q4. How did the average profit change over time?

select date_year, 
    date_month,
    sum(amount) as total_profit,
    round(avg(sum(amount)) over( 
        order by date_year, 
	    date_month
        rows between 1 preceding and current row
    ), 2) as moving_average
from pittsburgh_dataset
group by date_year, date_month
order by date_year, date_month;

-- Q5. What was the year-over-year difference in profit?

select date_year,
    sum(amount) as total_profit,
    lag(sum(amount)) over(
	order by date_year
    ) as previous_year,
    sum(amount) - lag(sum(amount)) over(
	order by date_year
    ) as YoY_difference
from pittsburgh_dataset
group by date_year
order by date_year;

-- Q6. What proportion did each object account contribute to total revenue? Total expense?

with revenue_summary as (
    select sum(amount) as total_revenue_all_dep
    from pittsburgh_dataset
    where ledger_description = 'REVENUES'
)
select 
    cp.object_account_description,
    sum(cp.amount) as total_revenue,
    (sum(cp.amount) / rs.total_revenue_all_dep) * 100 as percent_contribution
from pittsburgh_dataset as cp
join revenue_summary as rs
on cp.ledger_description = 'REVENUES'
group by cp.object_account_description, rs.total_revenue_all_dep
order by percent_contribution desc;

with expense_summary as (
    select sum(amount) as total_expense_all_dep
    from pittsburgh_dataset
    where ledger_description = 'EXPENSES'
)
select 
    cp.object_account_description,
    sum(cp.amount) as total_expense,
    (sum(cp.amount) / es.total_expense_all_dep) * 100 as percent_contribution
from pittsburgh_dataset as cp
join expense_summary as es
on cp.ledger_description = 'EXPENSES'
group by cp.object_account_description, es.total_expense_all_dep
order by percent_contribution desc;
