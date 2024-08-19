-- Cleaning Data in SQL 

select *
from portfolioproject.cityofpittsburgh;
    
show fields
from portfolioproject.cityofpittsburgh;

-- Converting Type

alter table cityofpittsburgh
modify column general_ledger_date date;

alter table cityofpittsburgh
modify column amount decimal(65,2);

-- Parsing and Splitting Data

alter table cityofpittsburgh
add column date_day int,
add column date_month int,
add column date_year int;

update cityofpittsburgh
set date_day = day(general_ledger_date),
	date_month = month(general_ledger_date),
    date_year = year(general_ledger_date);

-- Standardizing Formats 

alter table cityofpittsburgh
rename column _id to id,
rename column ledger_descrpition to ledger_description;

update cityofpittsburgh
set department_name = upper(department_name),
	ledger_description = upper(ledger_description),
    object_account_description = upper(object_account_description);

update cityofpittsburgh
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

update cityofpittsburgh
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

update cityofpittsburgh
set fund_description = replace(fund_description, '.', ''),
	object_account_description = replace(object_account_description, '.', '');

update cityofpittsburgh
set object_account_description = substring_index(object_account_description, '-', 1);

update cityofpittsburgh
set fund_description = replace(fund_description, '3', 'THREE'),
    fund_description = replace(fund_description, 'TRUST FUND', 'TF');

-- Correcting Inaccuracies 

update cityofpittsburgh
set department_name = 
	case when department_name = 'PERMITS LICENSES AND INSPECTIO' then 'PERMITS LICENSES AND INSPECTION'
		when department_name = 'OFFICE OF MANAGEMENT AND BUDG' then 'OFFICE OF MANAGEMENT AND BUDGET'
		else department_name
	end;

update cityofpittsburgh
set object_account_description = 
    case when object_account_description = 'PROPERTY CERTIFICATE APPLICATI' then 'PROPERTY CERTIFICATE APPLICATION'
		when object_account_description = 'ANIMAL CARE AND CONTROL REVENU' then 'ANIMAL CARE AND CONTROL REVENUE'
		when object_account_description = 'COMPUTER MAINTANACE' then 'COMPUTER MAINTENANCE'
		else object_account_description
	end;

update portfolioproject.cityofpittsburgh
set fund_description = replace(fund_description, 'TREE', 'THREE');

update portfolioproject.cityofpittsburgh
set amount = 
	case when ledger_description = 'EXPENSES' then -ABS(amount)
		when ledger_description = 'REVENUES' then ABS(amount)
	end;

select *
from portfolioproject.cityofpittsburgh
where coalesce (id, '') = '';

-- I cycled through the columns using the query above and there were no null/blank values

-- Removing Duplicates

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
		portfolioproject.cityofpittsburgh
)
select *
from rownumcte
where rownum > 1
order by fund_number;
	
-- Although it appears as though there are duplicates, there most likely are not
-- The City of Pittsburgh is audited on a regular basis
-- Any duplicates would be flagged as deficiencies
    
-- Deleting Unused Columns

alter table cityofpittsburgh
drop column cost_center_number,
drop column cost_center_description;

-- Exploring Data in SQL

-- Q1. How many revenue and expense reports were made?

select ledger_description,
	count(*) as report_count
from portfolioproject.cityofpittsburgh
group by ledger_description;

-- Q2. What was the distribution of departments by average revenue? Average expense?

select department_name,
	count(department_name) as department_count,
    round(avg(amount), 2) as avg_revenue
from portfolioproject.cityofpittsburgh
where ledger_description = 'REVENUES'
group by department_name
order by avg_revenue desc;

select department_name,
	count(department_name) as department_count,
    round(avg(amount), 2) as avg_expense
from portfolioproject.cityofpittsburgh
where ledger_description = 'EXPENSES'
group by department_name
order by avg_expense;

-- Q3. Which department had the highest total profit? Lowest?

select department_name,
	sum(amount) as total_profit
from portfolioproject.cityofpittsburgh
group by department_name
order by total_profit desc;

-- Q4. How did total profit for all departments change over time?

select general_ledger_date,
	sum(amount) as total_profit,
	sum(sum(amount)) over( 
		order by general_ledger_date 
        rows between unbounded preceding and current row
	) as running_total_profit
from portfolioproject.cityofpittsburgh
group by general_ledger_date
order by general_ledger_date;

-- Q5. What was the breakdown of revenue earned by each department? Expense incurred?

select department_name,
	object_account_description,
    sum(amount) as total_revenue
from portfolioproject.cityofpittsburgh
where ledger_description = 'REVENUES'
group by department_name,
	object_account_description
order by department_name, 
	total_revenue desc;

select department_name,
	object_account_description,
    sum(amount) as total_expense
from portfolioproject.cityofpittsburgh
where ledger_description = 'EXPENSES'
group by department_name,
	object_account_description
order by department_name, 
	total_expense;

-- Q6. What proportion did each object account contribute to total revenue? Total expense?

with revenue_summary as (
	select sum(amount) as total_revenue_all_dep
    from portfolioproject.cityofpittsburgh
    where ledger_description = 'REVENUES' 
)
select cp.object_account_description,
	sum(cp.amount) as total_revenue,
	(sum(cp.amount)/rs.total_revenue_all_dep) * 100 as percent_contribution
from portfolioproject.cityofpittsburgh as cp
cross join revenue_summary as rs
where ledger_description = 'REVENUES' 
group by cp.object_account_description, 
	rs.total_revenue_all_dep
order by percent_contribution desc;

with expense_summary as (
	select sum(amount) as total_expense_all_dep
    from portfolioproject.cityofpittsburgh
    where ledger_description = 'EXPENSES' 
)
select cp.object_account_description,
	sum(cp.amount) as total_expense,
	(sum(cp.amount)/es.total_expense_all_dep) * 100 as percent_contribution
from portfolioproject.cityofpittsburgh as cp
cross join expense_summary as es
where ledger_description = 'EXPENSES' 
group by cp.object_account_description, 
	es.total_expense_all_dep
order by percent_contribution desc;
