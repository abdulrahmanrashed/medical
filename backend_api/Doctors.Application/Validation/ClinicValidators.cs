using Doctors.Application.DTOs.Clinics;
using FluentValidation;

namespace Doctors.Application.Validation;

public class CreateClinicValidator : AbstractValidator<CreateClinicDto>
{
    public CreateClinicValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.ClinicAdminEmail).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(x => x.ClinicAdminPassword).NotEmpty().MinimumLength(8).MaximumLength(128);
        RuleFor(x => x.ClinicAdminFirstName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.ClinicAdminLastName).NotEmpty().MaximumLength(100);
    }
}

public class UpdateClinicValidator : AbstractValidator<UpdateClinicDto>
{
    public UpdateClinicValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
    }
}
