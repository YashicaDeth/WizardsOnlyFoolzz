import { Client } from 'file:///P:/GameDev/Tools/godot-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import { StdioClientTransport } from 'file:///P:/GameDev/Tools/godot-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import { writeFile } from 'node:fs/promises';

const transport = new StdioClientTransport({
  command: 'P:\\GameDev\\Tools\\node-v24.20.0-win-x64\\node.exe',
  args: ['P:\\GameDev\\Tools\\godot-mcp\\node_modules\\@satelliteoflove\\godot-mcp\\dist\\cli.js'],
  env: { ...process.env, GODOT_HOST: '127.0.0.1', GODOT_PORT: '6550', GODOT_MCP_USAGE_LOG: '0', TEMP: 'P:\\GameDev\\Temp', TMP: 'P:\\GameDev\\Temp' },
  stderr: 'pipe',
});
const client = new Client({name: 'allusions-setup-verification', version: '1.0.0'});
const errors = [];
transport.stderr?.on('data', data => errors.push(String(data)));
try {
  await client.connect(transport);
  const listed = await client.listTools();
  const selected = listed.tools.filter(tool => ['godot_editor_read','godot_editor_edit','godot_project'].includes(tool.name));
  await writeFile('P:\\GameDev\\AllusionsTooGrandeur\\setup\\mcp-schemas.json', JSON.stringify(selected, null, 2));
  let project;
  for (let attempt = 0; attempt < 10; attempt++) {
    project = await client.callTool({name: 'godot_project', arguments: {action: 'get_info'}});
    if (!project.isError) break;
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  if (project.isError) throw new Error(JSON.stringify(project));
  const addon = await client.callTool({name: 'godot_project', arguments: {action: 'addon_status'}});
  const editor = await client.callTool({name: 'godot_editor_read', arguments: {action: 'get_state'}});
  const logs = await client.callTool({name: 'godot_editor_read', arguments: {action: 'get_log_messages', severity: 'error', limit: 10}});
  const result = {verifiedAt: new Date().toISOString(), server: client.getServerVersion(), toolCount: listed.tools.length, project, addon, editor, logs};
  if ([addon, editor, logs].some(result => result.isError)) throw new Error(JSON.stringify(result));
  await writeFile('P:\\GameDev\\AllusionsTooGrandeur\\setup\\mcp-verification.json', JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
} finally {
  await client.close();
  await writeFile('P:\\GameDev\\AllusionsTooGrandeur\\setup\\logs\\mcp-client.log', errors.join(''));
}
