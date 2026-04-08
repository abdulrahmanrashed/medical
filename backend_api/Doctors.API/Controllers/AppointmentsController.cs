using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Appointments;
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

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<AppointmentDto>>> GetAll(
        [FromQuery] int? doctorId,
        CancellationToken cancellationToken)
    {
        return Ok(await _appointments.GetAllForCurrentUserAsync(doctorId, cancellationToken));
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

    [HttpDelete("{id:int}")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Reception}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _appointments.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
