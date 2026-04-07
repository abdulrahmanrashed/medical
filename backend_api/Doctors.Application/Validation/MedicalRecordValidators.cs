using Doctors.Application.DTOs.MedicalRecords;
using FluentValidation;

namespace Doctors.Application.Validation;

public class CreateMedicalRecordValidator : AbstractValidator<CreateMedicalRecordDto>
{
    public CreateMedicalRecordValidator()
    {
        RuleFor(x => x.PatientId).NotEmpty();
        RuleFor(x => x.ClinicId).GreaterThan(0);
    }
}

public class UpdateMedicalRecordValidator : AbstractValidator<UpdateMedicalRecordDto>
{
    public UpdateMedicalRecordValidator()
    {
        // All fields optional; doctor may clear text by sending empty string.
    }
}
