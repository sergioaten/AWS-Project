locals{
    ssm_ps = [
        {
            name    = "/cafe/dbUrl",
            value   = aws_db_instance.mysql.address
        },
        {
            name    = "/cafe/dbUser",
            value   = aws_db_instance.mysql.username
        },
        {
            name    = "/cafe/dbPassword",
            value   = aws_db_instance.mysql.password
        },
        {
            name    = "/cafe/dbName",
            value   = aws_db_instance.mysql.db_name
        },
        {
            name    = "/cafe/showServerInfo",
            value   = "true"
        },
        {
            name    = "/cafe/timeZone",
            value   = "Europe/Madrid"
        },
        {
            name    = "/cafe/currency",
            value   = "€"
        }
    ]

    public_azs  = var.subnet.public.azs
    private_azs = var.subnet.private.azs

    mypublicip = chomp(data.http.mypublicip.body)
}