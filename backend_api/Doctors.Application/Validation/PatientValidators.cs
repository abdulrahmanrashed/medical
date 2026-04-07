using Doctors.Application.Common;
using Doctors.Application.DTOs.Patients;
using FluentValidation;

namespace Doctors.Application.Validation;

public class LinkPatientClinicValidator : AbstractValidator<LinkPatientClinicDto>
{
    public LinkPatientClinicValidator()
    {
        RuleFor(x => x.PatientId).NotEmpty();
        RuleFor(x => x.ClinicId).GreaterThan(0);
    }
}

public class CreateDraftPatientValidator : AbstractValidator<CreateDraftPatientDto>
{
    public CreateDraftPatientValidator()
    {
        RuleFor(x => x.Phone).NotEmpty().MaximumLength(30);
        RuleFor(x => x.FullName).NotEmpty().MaximumLength(300);
    }
}

public class PhoneRegistrationLookupValidator : AbstractValidator<PhoneRegistrationLookupDto>
{
    public PhoneRegistrationLookupValidator()
    {
        RuleFor(x => x.Phone).NotEmpty().MaximumLength(30);
    }
}

public class ReceptionFindOrCreatePatientValidator : AbstractValidator<ReceptionFindOrCreatePatientDto>
{
    public ReceptionFindOrCreatePatientValidator()
    {
        RuleFor(x => x.Phone).NotEmpty().MaximumLength(30);
        RuleFor(x => x.FullName).MaximumLength(300);
    }
}

public class UpdatePatientProfileValidator : AbstractValidator<UpdatePatientProfileDto>
{
    public UpdatePatientProfileValidator()
    {
        RuleFor(x => x).Must(HasAnyField)
            .WithMessage("Provide at least one field to update.");
        RuleFor(x => x.Phone!)
            .Must(p => PhoneNormalizer.Normalize(p).Length > 0)
            .When(x => x.Phone is not null);
        RuleFor(x => x.FullName!)
            .NotEmpty()
            .When(x => x.FullName is not null);
        RuleFor(x => x.Email!).EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.Email));
        RuleFor(x => x.InsuranceDetails).MaximumLength(4000).When(x => x.InsuranceDetails is not null);
        RuleFor(x => x.ChronicDiseases).MaximumLength(4000).When(x => x.ChronicDiseases is not null);
    }

    private static bool HasAnyField(UpdatePatientProfileDto d) =>
        d.Phone is not null
        || d.Email is not null
        || d.FullName is not null
        || d.DateOfBirth is not null
        || d.InsuranceStatus is not null
        || d.InsuranceDetails is not null
        || d.ChronicDiseases is not null;
}
