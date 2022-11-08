/*
This demo answers the question:
    What would a Single Version of the Truth (SVOT) on Snowflake for Asset Managers look like?

Why Snowflake: Your benefits
    Significantly less cost of maintaining one high performance SVOT    
    SVOT makes trading, risk management, regulatory reporting, and all use cases significantly easier
    Unlimited Compute and Concurrency enable quick data-driven decisions

What we will see
    Use Data Marketplace to instantly get stock history
    Query trade, cash, positions, and PnL on 2 billion or more rows on Snowflake
    Use Window Functions to automate cash, position, and PnL reporting
    
*/


-----------------------------------------------------
--context
    use role finservam_admin; use warehouse finservam_devops_wh; use schema finservam.public;
    
    //if desired, resize compute - we start low to save money
    alter warehouse finservam_devops_wh set warehouse_size = 'small';

    /*. XSMALL SMALL MEDIUM LARGE XLARGE X2LARGE X3LARGE X4LARGE  */



-----------------------------------------------------
--View, table, and column comments for a data dictionary

    select table_type object_type, table_name object_name, comment /* JSON */
    from information_schema.tables
    where table_schema = 'PUBLIC' and comment is not null
        union all
    select 'COLUMN' object_type, table_name || '.' || column_name object_type, comment
    from information_schema.columns
    where table_schema = 'PUBLIC' and comment is not null
    order by 1,2;




    //what is the current PnL for trader charles? - view on trade table so always updated as trade populated
        select *
        from position_now where trader = 'charles'
        order by PnL desc;

                
        
    //see ranked PnL for a random trader - no indexes, statistics, vacuuming, maintenance
        set trader = (select top 1 trader from trader sample(10) where trader is not null);

        select symbol, date, trader, PM, cash_now, num_share_now, close, market_value, PnL
        from position_now
        where trader = $trader
        order by PnL desc;
        
        

    //option to disable cache
//        alter user set use_cached_result=false;  
//        alter user set use_cached_result=true; 

    //time-series: what is my position as-of a date?  
        //notice 24 hour global cache on 2nd execution
        set dt = '2019-01-01';

        select symbol, date, trader, cash_cumulative, num_shares_cumulative, close, market_value, PnL
        from position where date >= $dt and symbol = 'TSLA' and trader = 'charles'
        order by date;
        
        select top 300 * from trade;
        
        --metadata cache
        select count(*) from trade;
        

          //dynamic view using window functions so only pay storage for trade table; trade table drives all
              select get_ddl('view','position');   
              
              show tables like 'trade';

              






    //trade - date and quantity of buy, sell, or hold action on assets: This controls the position view
        select * 
        from trade 
        where date >= '2019-01-01' and symbol = 'AMZN' and trader = 'charles'
        order by symbol, date;          
        
            //ansi sql; comments for queryable metadata and data catalog
                select get_ddl('table','trade');   



//Cross-Database Joins 
    select sl.symbol, sl.date, sl.close, cp.exchange, cp.website, cp.description
    from finservam.public.stock_latest sl
    inner join zepl_us_stocks_daily.public.company_profile cp on sl.symbol = cp.symbol
    where sl.symbol = 'AMZN';





//Instant Real-Time Market Data with neither copying nor FTP
        //Query terabytes immediately
        select * 
        from zepl_us_stocks_daily.public.stock_history
        where symbol = 'SBUX'
        order by date desc;
        






----------------------------------------------------------------------------------------------------------
--Zero Copy Clone for instant dev,qa,sandboxes
use role accountadmin;
drop database if exists finservam_qa1;


create database finservam_qa1 clone finservam;



//Clones are zero additional storage cost; storage cost is only on deltas; 
//ie 1 TB in prod; change .1 TB in clone only pay for 1.1 automatically compressed TB
  select *
  from finservam.public.trade 
  where trader = 'charles' and symbol = 'AMZN';

  //we can change clones without impacting production
  select *
  from finservam_qa1.public.trade 
  where trader = 'charles' and symbol = 'AMZN';

//  delete
//  from finservam_qa1.public.trade 
//  where trader = 'charles' and symbol = 'GE';


  
  update finservam_qa1.public.trade set symbol = 'SNOW'
  where trader = 'charles' and symbol = 'AMZN';


  //we use Time Travel for DevOps & Rollbacks [configurable from 0-90 days]
    set queryID = last_query_id(); 
  
  
  //we can also set the queryID
      //
//      set queryID = '01a66082-0604-ab79-0000-7335021ce9ce';



  //we Time Travel to see before the (DML) delete
  select *
  from finservam_qa1.public.trade 
  before (statement => $queryid)
  where trader = 'charles' and symbol = 'AMZN';
  
  
  -----------------------------------------------------
  --UNDO our delete
  insert into finservam_qa1.public.trade 
  select *
  from finservam_qa1.public.trade 
  before (statement => $queryid)
  where trader = 'charles' and symbol = 'AMZN';
  
  
  -----------------------------------------------------
  --Undrop is also up to 90 days of Time Travel; DBAs and Release Managers sleep much better than backup & restore
  drop table finservam_qa1.public.trade;
  -- select count(*) from finservam_qa1.public.trade;
  undrop table finservam_qa1.public.trade;
  
  drop database finservam_qa1;
  -- select count(*) from finservam_qa1.public.trade;
  undrop database finservam_qa1;
  




  //if we don't want to wait for auto-suspend
    alter warehouse finservam_devops_wh suspend;

