using Amazon.Runtime.Internal;
using Amazon.SimpleEmail;
using Amazon.SimpleEmail.Model;
using API.AmazonSES.Controllers;
using API.AmazonSES.Services;
using System.Text.Json;

public class SESService : IMailService
{
    private readonly IAmazonSimpleEmailService _ses;
    private readonly IConfiguration _config;
    private readonly ILogger<SESService> _logger;
    public SESService(IAmazonSimpleEmailService ses, IConfiguration configuration, ILogger<SESService> logger)
    {
        _ses = ses;
        _config = configuration;
        _logger = logger;
    }

    public async Task EnviarEmailAsync(string toEmail, string subject, string body)
    {
        var sendRequest = new SendEmailRequest
        {
            Source = _config["EmailVerificado"], // Dirección de correo verificada
            Destination = new Destination
            {
                ToAddresses = new List<string> { toEmail }
            },
            Message = new Message
            {
                Subject = new Content(subject),
                Body = new Body
                {
                    Html = new Content(body) // Puedes usar Content(Text) si es texto plano
                }
            }
        };

        try
        {
            _logger.LogInformation(JsonSerializer.Serialize(sendRequest));
            var response = await _ses.SendEmailAsync(sendRequest);
            Console.WriteLine($"Correo electronico enviado! ID de mensaje: {response.MessageId}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error al enviar el mensaje: {ex.Message}");
            throw;
        }
    }

    public async Task<bool> VerificarEmail(string email)
    {
        var request = new VerifyEmailIdentityRequest
        {
            EmailAddress = email
        };

        try
        {
            _logger.LogInformation(JsonSerializer.Serialize(request));
            await _ses.VerifyEmailIdentityAsync(request);
            Console.WriteLine($"Verificación de email enviada: {email}");
            return true;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error al verificar email: {ex.Message}");
            return false;
        }
    }
}
