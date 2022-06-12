/*
This demo answers the question:
    What would a Single Version of the Truth (SVOT) on Snowflake for Asset Managers look like?

Why Snowflake: Your benefits
    Significantly less cost of maintaining one high performance SVOT    
    SVOT makes trading, risk management, and regulatory reporting significantly easier
    Unlimited Compute and Concurrency enable quick data-driven decisions

What we will see
    Use Data Marketplace to instantly get stock history
    Query trade, cash, positions, and PnL on Snowflake
    Use Window Functions to automate cash, position, and PnL reporting
    
*/



-----------------------------------------------------
--context
    use role finservam_admin; use warehouse finservam_devops_wh; use schema finservam.public;
    show warehouses like 'finservam%';
    //if desired, resize compute - we start low to save money
    alter warehouse finservam_devops_wh set warehouse_size = 'xsmall';

    /*. XSMALL SMALL MEDIUM LARGE XLARGE X2LARGE X3LARGE X4LARGE  */



-----------------------------------------------------
--View, table, and column comments for a data dictionary

    select table_type object_type, table_name object_name, comment
    from information_schema.tables
    where table_schema = 'PUBLIC' and comment is not null
        union all
    select 'COLUMN' object_type, table_name || '.' || column_name object_type, comment
    from information_schema.columns
    where table_schema = 'PUBLIC' and comment is not null
    order by 1,2;




    //what is the current PnL for trader charles? - view on trade table so always updated as trade populated
        //notice it is a non-materialized window function view on 2.5 billion rows
        select symbol, trader, PM, num_share_now, cash_now, close, date, PnL
        from position_now where trader = 'charles'
        order by PnL desc;
        
        


        
    //see ranked PnL for a random trader - no indexes, statistics, vacuuming, maintenance
        set trader = (select top 1 trader from trader sample(10) where trader is not null);

        select symbol, date, trader, PM, cash_now, num_share_now, close, market_value, PnL
        from position_now
        where trader = $trader
        order by PnL desc;
        
        


        
        


    //what is my position and PnL as-of a date?  
        //notice 24 hour global cache on 2nd execution
        //alter session set use_cached_result=false;  //disable global cache
        select symbol, date, trader, cash_cumulative, num_shares_cumulative, close, market_value, PnL
        from position where date >= '2019-01-01' and symbol = 'AMZN' and trader = 'charles'
        order by date;
        


          //dynamic view using window functions so only pay storage for trade table; trade table drives all
              select get_ddl('view','position');   
              









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
    where sl.symbol = 'AMZN'
    order by 1;





//Instant Real-Time Market Data
        //free stock_history from Data Marketplace
        //Factset / S&P: Instant access to entire catalog (Terabytes in seconds)
        select * 
        from zepl_us_stocks_daily.public.stock_history
        where symbol = 'SBUX'
        order by date desc;
        




    //we are done, we can wait for auto-suspend or suspend on demand to save credits
        show warehouses like 'finservam%';
        alter warehouse finservam_devops_wh suspend;


