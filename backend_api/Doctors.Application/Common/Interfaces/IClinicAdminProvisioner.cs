namespace Doctors.Application.Common.Interfaces;



/// <summary>Creates the clinic owner Identity user (ClinicAdmin) and links them to the clinic.</summary>

public interface IClinicAdminProvisioner

{

    Task<string> CreateAndLinkClinicAdminAsync(

        int clinicId,

        string email,

        string password,

        string firstName,

        string lastName,

        CancellationToken cancellationToken = default);

}

