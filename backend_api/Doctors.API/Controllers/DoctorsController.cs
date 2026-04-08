using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Doctors;
using Doctors.Domain.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Doctors.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DoctorsController : ControllerBase
{
    private readonly IDoctorService _doctors;

    public DoctorsController(IDoctorService doctors)
    {
        _doctors = doctors;
    }

    [HttpGet("clinic/{clinicId:int}")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Doctor},{AppRoles.Reception},{AppRoles.Patient},{AppRoles.ClinicAdmin}")]
    public async Task<ActionResult<IReadOnlyList<DoctorDto>>> GetByClinic(int clinicId, CancellationToken cancellationToken)
    {
        return Ok(await _doctors.GetByClinicAsync(clinicId, cancellationToken));
    }

    [HttpGet("{id:int}")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Doctor},{AppRoles.Reception},{AppRoles.Patient},{AppRoles.ClinicAdmin}")]
    public async Task<ActionResult<DoctorDto>> GetById(int id, CancellationToken cancellationToken)
    {
        return Ok(await _doctors.GetByIdAsync(id, cancellationToken));
    }

    [HttpGet("me")]
    [Authorize(Roles = AppRoles.Doctor)]
    public async Task<ActionResult<DoctorDto>> GetMine(CancellationToken cancellationToken)
    {
        var doctor = await _doctors.GetMineAsync(cancellationToken);
        if (doctor is null)
            return NotFound();
        return Ok(doctor);
    }

    [HttpPatch("{id:int}/active")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.ClinicAdmin}")]
    public async Task<ActionResult<DoctorDto>> SetActive(int id, [FromBody] SetDoctorActiveDto dto, CancellationToken cancellationToken)
    {
        return Ok(await _doctors.SetActiveAsync(id, dto.IsActive, cancellationToken));
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.ClinicAdmin}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _doctors.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
