using API.AmazonSES;

var builder = WebApplication.CreateBuilder(args);
{
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();
    builder.Services.AddConfigurationAmazon(builder.Configuration);
    builder.Configuration
        .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true) // Configuraci�n base
        .AddEnvironmentVariables(); // Sobrescribir con variables de entorno

    builder.Services.AddHealthChecks();
    builder.Services.AddCors(options => {
        options.AddPolicy("AllowAny",
                policy =>
                {
                    policy.AllowAnyOrigin()
                        .AllowAnyHeader()
                        .AllowAnyMethod();
                });
    });
}

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

//app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.MapHealthChecks("/health").AllowAnonymous();

app.UseCors("AllowAny");

app.Run();
