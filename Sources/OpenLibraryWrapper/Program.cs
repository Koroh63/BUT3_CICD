using System.Reflection;
using DtoAbstractLayer;
using LibraryDTO;
using Microsoft.OpenApi.Models;
using MyLibraryManager;
using OpenLibraryClient;
using StubbedDTO;

var builder = WebApplication.CreateBuilder(args);

var toto = System.Environment.GetEnvironmentVariable("SWITCH_CSHARP",System.EnvironmentVariableTarget.Process);
var username = System.Environment.GetEnvironmentVariable("ENV_MARIADB_USER",System.EnvironmentVariableTarget.Process);
var password = System.Environment.GetEnvironmentVariable("ENV_MARIADB_PASSWORD",System.EnvironmentVariableTarget.Process);
var db = System.Environment.GetEnvironmentVariable("ENV_MARIADB_DATABASE",System.EnvironmentVariableTarget.Process);
var rootPassword =System.Environment.GetEnvironmentVariable("ENV_MARIADB_ROOT_PASSWORD",System.EnvironmentVariableTarget.Process);
var host = System.Environment.GetEnvironmentVariable("ENV_MARIADB_HOST",System.EnvironmentVariableTarget.Process);
// Add services to the container.

switch (toto){
    case "api" :
        builder.Services.AddSingleton<IDtoManager,OpenLibClientAPI>();
        break;
    case "stub":
        builder.Services.AddSingleton<IDtoManager,Stub>();
        break;
    case "db":
        string connectionString = $"server={host};port=3306;database={db};uid={username};pwd={password};";
        builder.Services.AddSingleton<IDtoManager,MyLibraryMgr>(myLibraryMgr => new MyLibraryMgr(connectionString));
        break;

    default:
        Console.WriteLine("Error");
        break;
}

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();

var app = builder.Build();

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();