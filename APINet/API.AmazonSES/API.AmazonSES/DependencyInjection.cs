using Amazon.SimpleEmail;
using API.AmazonSES.Services;

namespace API.AmazonSES
{
    public static class DependecyInjection
    {
        public static IServiceCollection AddConfigurationAmazon(this IServiceCollection service, IConfiguration configuration)
        {
            service.AddDefaultAWSOptions(configuration.GetAWSOptions());
            service.AddAWSService<IAmazonSimpleEmailService>();
            service.AddTransient<IMailService, SESService>();
            return service;
        }
    }
}
