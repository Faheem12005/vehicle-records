import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("VehicleRegistryModule", (m) => {
    const vehicleRegistry = m.contract("VehicleRegistry");
    return { vehicleRegistry };
})