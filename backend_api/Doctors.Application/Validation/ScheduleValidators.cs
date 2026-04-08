using Doctors.Application.DTOs.Schedules;
using FluentValidation;

namespace Doctors.Application.Validation;

public class BulkDoctorWorkScheduleRequestValidator : AbstractValidator<BulkDoctorWorkScheduleRequestDto>
{
    public BulkDoctorWorkScheduleRequestValidator()
    {
        RuleFor(x => x.DoctorId).GreaterThan(0);
        RuleFor(x => x.Notes).MaximumLength(2000).When(x => !string.IsNullOrEmpty(x.Notes));
    }
}

public class UpdateDoctorWorkScheduleRequestValidator : AbstractValidator<UpdateDoctorWorkScheduleDto>
{
    public UpdateDoctorWorkScheduleRequestValidator()
    {
        RuleFor(x => x.Notes).MaximumLength(2000).When(x => !string.IsNullOrEmpty(x.Notes));
    }
}
