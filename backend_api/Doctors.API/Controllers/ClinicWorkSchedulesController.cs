using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Schedules;
using Doctors.Domain.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Doctors.API.Controllers;

[ApiController]
[Route("api/Clinics/{clinicId:int}/work-schedules")]
[Authorize(Roles = $"{AppRoles.Admin},{AppRoles.ClinicAdmin}")]
public class ClinicWorkSchedulesController : ControllerBase
{
    private readonly IDoctorWorkScheduleService _schedules;

    public ClinicWorkSchedulesController(IDoctorWorkScheduleService schedules)
    {
        _schedules = schedules;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<DoctorWorkScheduleDto>>> Get(
        int clinicId,
        [FromQuery] int? doctorId,
        [FromQuery] DateOnly? from,
        [FromQuery] DateOnly? to,
        CancellationToken cancellationToken)
    {
        return Ok(await _schedules.GetByClinicAsync(clinicId, doctorId, from, to, cancellationToken));
    }

    [HttpPost("bulk")]
    public async Task<ActionResult<IReadOnlyList<DoctorWorkScheduleDto>>> Bulk(
        int clinicId,
        [FromBody] BulkDoctorWorkScheduleRequestDto dto,
        CancellationToken cancellationToken)
    {
        return Ok(await _schedules.BulkUpsertAsync(clinicId, dto, cancellationToken));
    }
}
