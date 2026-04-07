using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Doctors.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class ClinicSubscriptionDates : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "LastPaymentDate",
                table: "Clinics",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "SubscriptionOverdueNotifiedAtUtc",
                table: "Clinics",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "SubscriptionStartDate",
                table: "Clinics",
                type: "datetime2",
                nullable: true);

            migrationBuilder.Sql(
                """
                UPDATE Clinics
                SET SubscriptionStartDate = CreatedAtUtc
                WHERE SubscriptionStartDate IS NULL
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "LastPaymentDate",
                table: "Clinics");

            migrationBuilder.DropColumn(
                name: "SubscriptionOverdueNotifiedAtUtc",
                table: "Clinics");

            migrationBuilder.DropColumn(
                name: "SubscriptionStartDate",
                table: "Clinics");
        }
    }
}
