using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Clinics;
using Doctors.Domain.Common;
using Doctors.Infrastructure.Identity;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Doctors.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ClinicsController : ControllerBase
{
    private readonly IClinicService _clinics;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ICurrentUserService _currentUser;

    public ClinicsController(
        IClinicService clinics,
        UserManager<ApplicationUser> userManager,
        ICurrentUserService currentUser)
    {
        _clinics = clinics;
        _userManager = userManager;
        _currentUser = currentUser;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<IReadOnlyList<ClinicDto>>> GetAll(CancellationToken cancellationToken)
    {
        return Ok(await _clinics.GetAllAsync(cancellationToken));
    }

    [HttpGet("{id:int}")]
    [AllowAnonymous]
    public async Task<ActionResult<ClinicDto>> GetById(int id, CancellationToken cancellationToken)
    {
        return Ok(await _clinics.GetByIdAsync(id, cancellationToken));
    }

    [HttpPost]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<ActionResult<ClinicDto>> Create([FromBody] CreateClinicDto dto, CancellationToken cancellationToken)
    {
        var created = await _clinics.CreateAsync(dto, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<ActionResult<ClinicDto>> Update(int id, [FromBody] UpdateClinicDto dto, CancellationToken cancellationToken)
    {
        return Ok(await _clinics.UpdateAsync(id, dto, cancellationToken));
    }

    [HttpPatch("{id:int}/payment-status")]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<ActionResult<ClinicDto>> SetPaymentStatus(
        int id,
        [FromBody] SetClinicPaymentStatusDto dto,
        CancellationToken cancellationToken)
    {
        return Ok(await _clinics.SetPaymentStatusAsync(id, dto.PaymentStatus, cancellationToken));
    }

    [HttpGet("{id:int}/receptionists")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.ClinicAdmin}")]
    public async Task<ActionResult<List<ReceptionistSummaryDto>>> GetReceptionists(int id, CancellationToken cancellationToken)
    {
        if (User.IsInRole(AppRoles.ClinicAdmin))
        {
            var mine = _currentUser.GetAssignedClinicId();
            if (mine != id)
                return Forbid();
        }

        var users = await _userManager.Users
            .AsNoTracking()
            .Where(u => u.AssignedClinicId == id)
            .ToListAsync(cancellationToken);

        var list = new List<ReceptionistSummaryDto>();
        foreach (var u in users)
        {
            if (await _userManager.IsInRoleAsync(u, AppRoles.Reception))
            {
                list.Add(new ReceptionistSummaryDto
                {
                    UserId = u.Id,
                    Email = u.Email ?? string.Empty,
                    FirstName = u.FirstName,
                    LastName = u.LastName,
                });
            }
        }

        return Ok(list);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = AppRoles.Admin)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _clinics.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
