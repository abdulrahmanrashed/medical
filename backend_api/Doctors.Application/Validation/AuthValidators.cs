using Doctors.Application.DTOs.Auth;
using FluentValidation;

namespace Doctors.Application.Validation;

public class LoginRequestValidator : AbstractValidator<LoginRequestDto>
{
    public LoginRequestValidator()
    {
        RuleFor(x => x.Password).NotEmpty();
        RuleFor(x => x)
            .Must(d => !string.IsNullOrWhiteSpace(d.Email) || !string.IsNullOrWhiteSpace(d.Phone))
            .WithMessage("Provide email (staff) or phone (patient).");
        RuleFor(x => x.Email!).EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.Email));
    }
}

public class RegisterPatientRequestValidator : AbstractValidator<RegisterPatientRequestDto>
{
    public RegisterPatientRequestValidator()
    {
        RuleFor(x => x.Phone).NotEmpty().MaximumLength(30);
        RuleFor(x => x.Password).MinimumLength(8);
        RuleFor(x => x.FullName).NotEmpty().MaximumLength(300);
        RuleFor(x => x.Email).EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.Email));
        RuleFor(x => x.InsuranceDetails).MaximumLength(4000).When(x => !string.IsNullOrEmpty(x.InsuranceDetails));
        RuleFor(x => x.ChronicDiseases).MaximumLength(4000).When(x => !string.IsNullOrEmpty(x.ChronicDiseases));
    }
}

public class RegisterDoctorRequestValidator : AbstractValidator<RegisterDoctorRequestDto>
{
    public RegisterDoctorRequestValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Password).MinimumLength(8);
        RuleFor(x => x.FirstName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.LastName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.ClinicId).GreaterThan(0);
        RuleFor(x => x.Specialization).NotEmpty().MaximumLength(200);
    }
}

public class RegisterReceptionRequestValidator : AbstractValidator<RegisterReceptionRequestDto>
{
    public RegisterReceptionRequestValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Password).MinimumLength(8);
        RuleFor(x => x.FirstName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.LastName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.ClinicId).GreaterThan(0);
    }
}
