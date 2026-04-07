using System.Reflection;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.Mapping;
using Doctors.Application.Services;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;

namespace Doctors.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddAutoMapper(typeof(MappingProfile));
        services.AddValidatorsFromAssembly(Assembly.GetExecutingAssembly());

        services.AddScoped<IClinicService, ClinicService>();
        services.AddScoped<IDoctorService, DoctorService>();
        services.AddScoped<IPatientService, PatientService>();
        services.AddScoped<IPatientClinicLinkService, PatientClinicLinkService>();
        services.AddScoped<IAppointmentService, AppointmentService>();
        services.AddScoped<IMedicalRecordService, MedicalRecordService>();
        services.AddScoped<INotificationService, NotificationService>();

        return services;
    }
}
