using API.AmazonSES.Models;
using API.AmazonSES.Services;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace API.AmazonSES.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class EmailController : ControllerBase
    {
        private readonly IMailService _mailService;
        private readonly ILogger<EmailController> _logger;

        public EmailController(IMailService mailService, ILogger<EmailController> logger)
        {
            _mailService = mailService;
            _logger = logger;
        }

        [HttpPost("enviar-email")]
        public async Task<IActionResult> SendEmail([FromBody] MailRequest request)
        {
            _logger.LogInformation(JsonSerializer.Serialize(request));
            await _mailService.EnviarEmailAsync(request.ToEmail, request.Subject, request.Body);
            return Ok(new { ok = true, result ="Email enviado!"});
        }
        
        [HttpPost("verificar-email")]
        public async Task<IActionResult> VerifyEmail([FromBody] Email request)
        {
            _logger.LogInformation(JsonSerializer.Serialize(request));
            var result = await _mailService.VerificarEmail(request.VerificarEmail);
            if (result)
                return Ok(new { ok = true, result = "Verificación de email enviada" });
            else
                return StatusCode(500, new { ok = false, result = "Error al enviar la verificación de email" });
        }
    }
}
