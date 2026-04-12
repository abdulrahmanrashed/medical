using Doctors.Application.DTOs.Appointments;
using FluentValidation;

namespace Doctors.Application.Validation;

public class CreateAppointmentValidator : AbstractValidator<CreateAppointmentDto>
{
    public CreateAppointmentValidator()
    {
        RuleFor(x => x.PatientId).NotEmpty();
        RuleFor(x => x.ClinicId).GreaterThan(0);
        RuleFor(x => x.PatientName).NotEmpty().MaximumLength(200);
        RuleFor(x => x.PhoneNumber).NotEmpty().MaximumLength(30);
        RuleFor(x => x.DoctorNotes).MaximumLength(4000);
        RuleFor(x => x.ReceptionNotes).MaximumLength(4000);
        RuleFor(x => x.SpecializedDataJson).MaximumLength(8000).When(x => !string.IsNullOrEmpty(x.SpecializedDataJson));
    }
}

public class UpdateAppointmentValidator : AbstractValidator<UpdateAppointmentDto>
{
    public UpdateAppointmentValidator()
    {
        RuleFor(x => x.PatientName).NotEmpty().MaximumLength(200);
        RuleFor(x => x.PhoneNumber).NotEmpty().MaximumLength(30);
        RuleFor(x => x.DoctorNotes).MaximumLength(4000);
        RuleFor(x => x.ReceptionNotes).MaximumLength(4000);
        RuleFor(x => x.SpecializedDataJson).MaximumLength(8000).When(x => !string.IsNullOrEmpty(x.SpecializedDataJson));
    }
}

public class DoctorUpdateAppointmentSessionValidator : AbstractValidator<DoctorUpdateAppointmentSessionDto>
{
    public DoctorUpdateAppointmentSessionValidator()
    {
        RuleFor(x => x.DoctorNotes).MaximumLength(4000).When(x => x.DoctorNotes is not null);
        RuleFor(x => x.SpecializedDataJson).MaximumLength(8000).When(x => x.SpecializedDataJson is not null);
    }
}
