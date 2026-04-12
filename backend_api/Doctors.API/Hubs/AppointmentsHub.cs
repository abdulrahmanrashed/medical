using System.Linq;
using System.Security.Claims;
using Doctors.Application.Common.Interfaces;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Doctors.Infrastructure.Identity;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Doctors.API.Hubs;

[Authorize]
public class AppointmentsHub : Hub
{
    private readonly IRepository<Doctor> _doctors;

    public AppointmentsHub(IRepository<Doctor> doctors)
    {
        _doctors = doctors;
    }

    /// <summary>Reception staff: full appointment payloads including reception notes.</summary>
    public async Task SubscribeReceptionClinic(int clinicId)
    {
        if (!Context.User!.IsInRole(AppRoles.Reception))
            throw new HubException("Only reception can join this group.");
        var assigned = ParseInt(FindClaim(Context.User, JwtClaimNames.AssignedClinicId));
        if (assigned != clinicId)
            throw new HubException("Clinic mismatch.");
        await Groups.AddToGroupAsync(Context.ConnectionId, ReceptionGroup(clinicId));
    }

    /// <summary>Doctors: payloads exclude reception-only notes.</summary>
    public async Task SubscribeDoctorClinic(int clinicId)
    {
        if (!Context.User!.IsInRole(AppRoles.Doctor))
            throw new HubException("Only doctors can join this group.");
        var doctorId = ParseInt(FindClaim(Context.User, JwtClaimNames.DoctorId))
            ?? throw new HubException("Doctor id missing.");
        var doctor = await _doctors.GetByIdAsync(doctorId, Context.ConnectionAborted);
        if (doctor is null || doctor.ClinicId != clinicId)
            throw new HubException("Clinic mismatch.");
        await Groups.AddToGroupAsync(Context.ConnectionId, DoctorGroup(clinicId));
    }

    public async Task SubscribePatient(string patientIdStr)
    {
        if (!Context.User!.IsInRole(AppRoles.Patient))
            throw new HubException("Only patients can join this group.");
        if (!Guid.TryParse(patientIdStr, out var pid))
            throw new HubException("Invalid patient id.");
        var claim = FindClaim(Context.User, JwtClaimNames.PatientId);
        if (!Guid.TryParse(claim, out var myId) || myId != pid)
            throw new HubException("Patient mismatch.");
        await Groups.AddToGroupAsync(Context.ConnectionId, PatientGroup(pid));
    }

    public async Task SubscribeAdmin()
    {
        if (!Context.User!.IsInRole(AppRoles.Admin))
            throw new HubException("Only admins can join this group.");
        await Groups.AddToGroupAsync(Context.ConnectionId, "admin");
    }

    public static string ReceptionGroup(int clinicId) => $"reception-clinic-{clinicId}";
    public static string DoctorGroup(int clinicId) => $"doctor-clinic-{clinicId}";
    public static string PatientGroup(Guid patientId) => $"patient-{patientId:D}";

    private static int? ParseInt(string? s) => int.TryParse(s, out var v) ? v : null;

    private static string? FindClaim(ClaimsPrincipal? user, string claimType) =>
        user?.Claims.FirstOrDefault(c => c.Type == claimType)?.Value;
}
