using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Schedules;
using Doctors.Domain.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Doctors.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = $"{AppRoles.Admin},{AppRoles.ClinicAdmin}")]
public class DoctorWorkSchedulesController : ControllerBase
{
    private readonly IDoctorWorkScheduleService _schedules;

    public DoctorWorkSchedulesController(IDoctorWorkScheduleService schedules)
    {
        _schedules = schedules;
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<DoctorWorkScheduleDto>> Update(
        int id,
        [FromBody] UpdateDoctorWorkScheduleDto dto,
        CancellationToken cancellationToken)
    {
        return Ok(await _schedules.UpdateAsync(id, dto, cancellationToken));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _schedules.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
