import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("VehicleRegistryModule", (m) => {
    const vehicleRegistry = m.contract("VehicleRegistry");
    const roleRequestManager = m.contract("RoleRequestManager", [vehicleRegistry]);
    return { vehicleRegistry, roleRequestManager };
})