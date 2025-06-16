    jdbc_driver_library => "/opt/logstash/drivers/mssql-jdbc-12.4.2.jre8.jar"
    jdbc_driver_class => "com.microsoft.sqlserver.jdbc.SQLServerDriver"
    
    # SQL Server connection string with integrated security
    jdbc_connection_string => "jdbc:sqlserver://your-server:1433;databaseName=your_database;integratedSecurity=true;authenticationScheme=JavaKerberos"
    
    # Service account credentials
    jdbc_user => "DOMAIN\\service-account-name"
    jdbc_password => "service-account-password"
