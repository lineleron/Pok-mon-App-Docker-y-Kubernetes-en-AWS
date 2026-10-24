using API.AmazonSES.Models;

namespace API.AmazonSES.Services
{
    public interface IMailService
    {
        Task EnviarEmailAsync(string toEmail, string subject, string body);
        Task<bool> VerificarEmail(string email);
    }
}