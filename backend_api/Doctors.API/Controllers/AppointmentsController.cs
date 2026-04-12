using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Appointments;
using Doctors.Application.DTOs.MedicalFiles;
using Doctors.Domain.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Doctors.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AppointmentsController : ControllerBase
{
    private readonly IAppointmentService _appointments;

    public AppointmentsController(IAppointmentService appointments)
    {
        _appointments = appointments;
    }

    /// <summary>Offset pagination; default page size 10. Optional scheduled window in UTC.</summary>
    [HttpGet]
    public async Task<ActionResult<PagedAppointmentsDto>> GetPage(
        [FromQuery] int? doctorId,
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] DateTime? scheduledFromUtc = null,
        [FromQuery] DateTime? scheduledToUtc = null,
        CancellationToken cancellationToken = default)
    {
        return Ok(await _appointments.GetPageForCurrentUserAsync(
            doctorId,
            pageNumber,
            pageSize,
            scheduledFromUtc,
            scheduledToUtc,
            cancellationToken));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<AppointmentDto>> GetById(int id, CancellationToken cancellationToken)
    {
        return Ok(await _appointments.GetByIdAsync(id, cancellationToken));
    }

    [HttpPost]
    [Authorize(Roles = $"{AppRoles.Patient},{AppRoles.Admin},{AppRoles.Reception}")]
    public async Task<ActionResult<AppointmentDto>> Create([FromBody] CreateAppointmentDto dto, CancellationToken cancellationToken)
    {
        var created = await _appointments.CreateAsync(dto, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Reception}")]
    public async Task<ActionResult<AppointmentDto>> Update(int id, [FromBody] UpdateAppointmentDto dto, CancellationToken cancellationToken)
    {
        return Ok(await _appointments.UpdateAsync(id, dto, cancellationToken));
    }

    /// <summary>Doctor: start session (InProgress) or end session (Completed).</summary>
    [HttpPatch("{id:int}/doctor-status")]
    [Authorize(Roles = AppRoles.Doctor)]
    public async Task<ActionResult<AppointmentDto>> UpdateStatusByDoctor(
        int id,
        [FromBody] DoctorAppointmentStatusDto dto,
        CancellationToken cancellationToken)
    {
        return Ok(await _appointments.UpdateStatusByDoctorAsync(id, dto.Status, cancellationToken));
    }

    /// <summary>Doctor: update session notes and type-specific JSON without reception-only fields.</summary>
    [HttpPatch("{id:int}/doctor-session")]
    [Authorize(Roles = AppRoles.Doctor)]
    public async Task<ActionResult<AppointmentDto>> UpdateSessionByDoctor(
        int id,
        [FromBody] DoctorUpdateAppointmentSessionDto dto,
        CancellationToken cancellationToken)
    {
        return Ok(await _appointments.UpdateSessionByDoctorAsync(id, dto, cancellationToken));
    }

    /// <summary>Doctor: replace all appointment-level prescription lines (patient reminder schedule).</summary>
    [HttpPut("{id:int}/prescriptions")]
    [Authorize(Roles = AppRoles.Doctor)]
    public async Task<ActionResult<AppointmentDto>> ReplacePrescriptions(
        int id,
        [FromBody] ReplaceAppointmentPrescriptionsDto dto,
        CancellationToken cancellationToken)
    {
        return Ok(await _appointments.ReplaceAppointmentPrescriptionsAsync(id, dto, cancellationToken));
    }

    /// <summary>Staff: files uploaded by the patient for this visit (or general uploads for this patient).</summary>
    [HttpGet("{id:int}/patient-uploads")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Reception},{AppRoles.Doctor}")]
    public async Task<ActionResult<IReadOnlyList<MedicalFileDto>>> GetPatientUploads(
        int id,
        [FromServices] IMedicalFileService files,
        CancellationToken cancellationToken)
    {
        return Ok(await files.GetForAppointmentAsync(id, cancellationToken));
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Reception}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _appointments.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
