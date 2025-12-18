# Sistema de Evento onAttack para TFS 1.4.2

Este documento descreve todas as modificações necessárias para implementar o evento `onAttack` que dispara a cada ataque físico do player.

## Visão Geral

O evento `onAttack` é um novo tipo de CreatureEvent que é chamado toda vez que um player executa um ataque físico com sucesso. Isso permite criar animações de ataque, efeitos visuais, ou qualquer outra lógica que precise ser executada a cada hit.

---

## Arquivos Modificados

### 1. Source C++ (Requer Recompilação)

#### `src/creatureevent.h`

**Linha ~30** - Adicionar ao enum `CreatureEventType_t`:
```cpp
CREATURE_EVENT_EXTENDED_OPCODE, // otclient additional network opcodes
CREATURE_EVENT_ATTACK, // physical attack event  ← ADICIONAR
};
```

**Linha ~75** - Adicionar declaração da função:
```cpp
void executeExtendedOpcode(Player* player, uint8_t opcode, const std::string& buffer);
void executeOnAttack(Creature* creature, Creature* target);  // ← ADICIONAR
//
```

---

#### `src/creatureevent.cpp`

**Linha ~6** - Adicionar include:
```cpp
#include "creatureevent.h"

#include "creature.h"  // ← ADICIONAR
#include "item.h"
#include "tools.h"
```

**Linha ~208** - Em `configureEvent()`, adicionar:
```cpp
} else if (tmpStr == "extendedopcode") {
    type = CREATURE_EVENT_EXTENDED_OPCODE;
} else if (tmpStr == "attack") {           // ← ADICIONAR
    type = CREATURE_EVENT_ATTACK;          // ← ADICIONAR
} else {
```

**Linha ~260** - Em `getScriptEventName()`, adicionar:
```cpp
case CREATURE_EVENT_EXTENDED_OPCODE:
    return "onExtendedOpcode";

case CREATURE_EVENT_ATTACK:    // ← ADICIONAR
    return "onAttack";         // ← ADICIONAR

case CREATURE_EVENT_NONE:
```

**Final do arquivo** - Adicionar função `executeOnAttack()`:
```cpp
void CreatureEvent::executeOnAttack(Creature* creature, Creature* target) {
    //onAttack(creature, target)
    std::cout << "[onAttack] Player: " << creature->getName() << " attacking: " << (target ? target->getName() : "null") << std::endl;
    
    if (!lua::reserveScriptEnv()) {
        std::cout << "[Error - CreatureEvent::executeOnAttack] Call stack overflow" << std::endl;
        return;
    }

    ScriptEnvironment* env = lua::getScriptEnv();
    env->setScriptId(scriptId, scriptInterface);

    lua_State* L = scriptInterface->getLuaState();

    scriptInterface->pushFunction(scriptId);
    lua::pushUserdata(L, creature);
    lua::setCreatureMetatable(L, -1, creature);
    
    if (target) {
        lua::pushUserdata(L, target);
        lua::setCreatureMetatable(L, -1, target);
    } else {
        lua_pushnil(L);
    }
    
    scriptInterface->callVoidFunction(2);
}
```

---

#### `src/luascript.cpp`

**Linha ~3235** - Adicionar registro do método:
```cpp
registerMethod(L, "CreatureEvent", "onExtendedOpcode", LuaScriptInterface::luaCreatureEventOnCallback);
registerMethod(L, "CreatureEvent", "onAttack", LuaScriptInterface::luaCreatureEventOnCallback);  // ← ADICIONAR
```

---

#### `src/player.cpp`

**Linha ~3153** - Em `Player::doAttacking()`, modificar o bloco `if (result)`:
```cpp
if (result) {
    lastAttack = OTSYS_TIME();
    
    std::cout << "[DEBUG] Player::doAttacking - Attack successful for: " << getName() << std::endl;
    
    // Fire onAttack event for attack animations
    const auto& events = getCreatureEvents(CREATURE_EVENT_ATTACK);
    std::cout << "[DEBUG] Number of onAttack events registered: " << events.size() << std::endl;
    for (CreatureEvent* creatureEvent : events) {
        creatureEvent->executeOnAttack(this, attackedCreature);
    }
}
```

> **Nota**: Os logs de debug podem ser removidos após confirmar o funcionamento.

---

### 2. Scripts Lua (Não requer recompilação)

#### `data/creaturescripts/creaturescripts.xml`

Adicionar antes de `</creaturescripts>`:
```xml
<event type="attack" name="AttackAnimation" script="attack_animation.lua" />
```

---

#### `data/creaturescripts/scripts/login.lua`

Adicionar na seção `-- Events`:
```lua
-- Events
player:registerEvent("PlayerDeath")
player:registerEvent("DropLoot")
player:registerEvent("AttackAnimation")  -- ← ADICIONAR
return true
```

---

#### `data/creaturescripts/scripts/attack_animation.lua` (NOVO ARQUIVO)

```lua
-- Attack Animation Script using onAttack event
-- This event fires every time the player lands a physical attack

local config = {
    attackOutfit = {lookType = 24, lookHead = 0, lookBody = 0, lookLegs = 0, lookFeet = 0, lookAddons = 0},
    duration = 700, -- milliseconds
    maxDistance = 1, -- only trigger when adjacent to target
    lockDirection = true -- turn to face the target
}

local animationData = {}

local function getDirectionTo(fromPos, toPos)
    local dx = toPos.x - fromPos.x
    local dy = toPos.y - fromPos.y
    
    if math.abs(dx) > math.abs(dy) then
        return dx > 0 and DIRECTION_EAST or DIRECTION_WEST
    else
        return dy > 0 and DIRECTION_SOUTH or DIRECTION_NORTH
    end
end

local function getDistanceBetween(fromPos, toPos)
    return math.max(math.abs(fromPos.x - toPos.x), math.abs(fromPos.y - toPos.y))
end

function onAttack(creature, target)
    print("[LUA onAttack] Called! Creature: " .. (creature and creature:getName() or "nil") .. " Target: " .. (target and target:getName() or "nil"))
    
    if not creature or not target then
        return
    end
    
    local playerId = creature:getId()
    local creaturePos = creature:getPosition()
    local targetPos = target:getPosition()
    
    if creaturePos.z ~= targetPos.z then
        return
    end
    
    if getDistanceBetween(creaturePos, targetPos) > config.maxDistance then
        return
    end
    
    if animationData[playerId] then
        return
    end
    
    animationData[playerId] = {
        outfit = creature:getOutfit(),
        direction = creature:getDirection()
    }
    
    if config.lockDirection then
        creature:setDirection(getDirectionTo(creaturePos, targetPos))
    end
    
    local newOutfit = {
        lookType = config.attackOutfit.lookType,
        lookHead = config.attackOutfit.lookHead,
        lookBody = config.attackOutfit.lookBody,
        lookLegs = config.attackOutfit.lookLegs,
        lookFeet = config.attackOutfit.lookFeet,
        lookAddons = config.attackOutfit.lookAddons,
        lookMount = animationData[playerId].outfit.lookMount or 0
    }
    creature:setOutfit(newOutfit)
    
    addEvent(function(pid)
        local p = Player(pid)
        if p then
            local data = animationData[pid]
            if data then
                p:setOutfit(data.outfit)
            end
        end
        animationData[pid] = nil
    end, config.duration, playerId)
end
```

---

## Configuração

No arquivo `attack_animation.lua`, você pode ajustar:

| Parâmetro | Descrição | Valor Padrão |
|-----------|-----------|--------------|
| `attackOutfit.lookType` | ID do outfit durante o ataque | 24 |
| `duration` | Duração da animação em ms | 700 |
| `maxDistance` | Distância máxima para ativar (1 = adjacente) | 1 |
| `lockDirection` | Se deve virar para o alvo | true |

---

## Instalação

1. **Modifique os arquivos C++** conforme descrito acima
2. **Recompile o servidor** com Visual Studio
3. **Copie o novo executável** para substituir o antigo
4. **Adicione/modifique os scripts Lua** conforme descrito
5. **Reinicie o servidor**
6. **Relogue** com seu personagem

---

## Logs de Debug

Ao atacar, você verá no console:
```
[DEBUG] Player::doAttacking - Attack successful for: PlayerName
[DEBUG] Number of onAttack events registered: 1
[onAttack] Player: PlayerName attacking: MonsterName
[LUA onAttack] Called! Creature: PlayerName Target: MonsterName
```

> Após confirmar o funcionamento, remova os prints de debug do C++ e Lua.

---

## Troubleshooting

| Problema | Causa | Solução |
|----------|-------|---------|
| "Invalid type for creature event" | Executável antigo | Substitua pelo novo executável compilado |
| Não aparece nenhum log | Ataque não está tendo sucesso | Verifique se está causando dano |
| "0 events registered" | Evento não registrado no login | Verifique login.lua e creaturescripts.xml |
| Log C++ ok, mas Lua não | Problema no executeOnAttack | Verifique se o script Lua tem erros |
